#include "ruby.h"
#include <sstream>
#include <re2/re2.h>
#include <netlify-redirects/parser.hpp>
#include <netlify-redirects/rule.hpp>
#include <netlify-redirects/request.hpp>
#include <netlify-redirects/matcher.hpp>
#include <cstdio>

using std::nothrow;
using re2::StringPiece;

static VALUE Redirector = Qnil;

static VALUE rbString(std::string str) {
  return rb_str_new(str.c_str(), str.size());
}

static std::string stdString(VALUE string) {
  switch (TYPE(string)) {
    case T_STRING:
      return std::string(RSTRING_PTR(string), RSTRING_LEN(string));
    case T_SYMBOL:
      string = rb_funcall(string, rb_intern("to_s"), 0);
      return std::string(RSTRING_PTR(string), RSTRING_LEN(string));
    default:
      return "";
  }
}

static VALUE ruleToHash(const Rule &rule) {
  VALUE hash = rb_hash_new();
  rb_hash_aset(hash, ID2SYM(rb_intern("path")), rbString(rule.from));
  rb_hash_aset(hash, ID2SYM(rb_intern("to")), rbString(rule.to));
  rb_hash_aset(hash, ID2SYM(rb_intern("status")), INT2NUM(rule.status));
  if (!rule.host.empty()) {
    rb_hash_aset(hash, ID2SYM(rb_intern("host")), rbString(rule.host));
  }
  if (!rule.scheme.empty()) {
    rb_hash_aset(hash, ID2SYM(rb_intern("scheme")), rbString(rule.scheme));
  }
  if (rule.force) {
    rb_hash_aset(hash, ID2SYM(rb_intern("force")), Qtrue);
  }
  if (rule.isProxy()) {
    rb_hash_aset(hash, ID2SYM(rb_intern("proxy")), Qtrue);
  }
  if (!rule.conditions.empty()) {
    VALUE conditions = rb_hash_new();
    for (auto iter : rule.conditions) {
      rb_hash_aset(conditions, rbString(iter.key), rbString(iter.value));
    }
    rb_hash_aset(hash, ID2SYM(rb_intern("conditions")), conditions);
  }
  if (!rule.params.empty()) {
    VALUE params = rb_hash_new();
    for (auto iter : rule.params) {
      rb_hash_aset(params, ID2SYM(rb_intern(iter.key.c_str())), rbString(iter.value));
    }
    rb_hash_aset(hash, ID2SYM(rb_intern("params")), params);
  }
  return hash;
}

static VALUE resultToMatch(const MatchResult &result) {
  VALUE hash = rb_hash_new();
  if (result.isMatch()) {
    VALUE rbRule = rb_hash_new();
    rb_hash_aset(rbRule, ID2SYM(rb_intern("to")), rbString(result.match->to));
    rb_hash_aset(rbRule, ID2SYM(rb_intern("status")), INT2NUM(result.match->status));
    if (result.match->forceMatch) {
      rb_hash_aset(rbRule, ID2SYM(rb_intern("force")), Qtrue);
    }
    rb_hash_aset(hash, ID2SYM(rb_intern("rule")), rbRule);
  }
  if (!result.conditions.empty()) {
    VALUE conditions = rb_hash_new();
    for (auto &kv : result.conditions) {
      std::string r = "";
      for (auto &condition : kv.second) {
        r = r.empty() ? condition : r + "," + condition;
      }
      rb_hash_aset(conditions, rbString(kv.first), rbString(r));
    }
    rb_hash_aset(hash, ID2SYM(rb_intern("conditions")), conditions);
  }
  if (!result.exceptions.empty()) {
    VALUE exceptions = rb_hash_new();
    for (auto &kv : result.exceptions) {
      std::string r = "";
      for (auto &exception : kv.second) {
        r = r.empty() ? exception : r + "," + exception;
      }
      rb_hash_aset(exceptions, rbString(kv.first), rbString(r));
    }
    rb_hash_aset(hash, ID2SYM(rb_intern("exceptions")), exceptions);
  }
  if (!result.isMatch() && result.force404) {
    rb_hash_aset(hash, ID2SYM(rb_intern("force_404")), Qtrue);
  }
  return hash;
}

class RequestWrapper : public Request
{
public:
  RequestWrapper(VALUE request) : request(request) {
    env = rb_funcall(request, rb_intern("env"), 0);
  };
  const std::string getHost() {
    if (!host.empty()) return host;
    host = stdString(rb_funcall(request, rb_intern("host"), 0));
    return host;
  };
  const std::string getScheme() {
    if (!scheme.empty()) return scheme;
    scheme = stdString(rb_funcall(request, rb_intern("scheme"), 0));
    return scheme;
  };
  const std::string getPath() {
    if (!path.empty()) return path;
    path = stdString(rb_funcall(request, rb_intern("path"), 0));
    return path;
  };
  const std::string getQuery() {
    if (!query.empty()) return query;
    query = stdString(rb_funcall(request, rb_intern("query_string"), 0));
    return query;
  };
  const std::string getHeader(const std::string &name) {
    std::string &result = headers[name];
    if (!result.empty()) {
      return result;
    }
    if (name == "X-Country") {
      headers["X-Country"] = stdString(rb_hash_aref(env, rbString("HTTP_X_COUNTRY")));
    }
    if (name == "X-Language") {
      headers["X-Language"] = stdString(rb_hash_aref(env, rbString("HTTP_X_LANGUAGE")));
    }

    return result;
  };
  const std::string getCookieValue(const std::string &key) {
    std::string &result = cookieValues[key];
    if (!result.empty()) {
      return result;
    }
    VALUE cookie = rb_funcall(request, rb_intern("cookies"), 0);
    if (RTEST(cookie)) {
      cookieValues[key] = stdString(rb_hash_aref(cookie, rbString(key)));
    }
    return result;
  }
private:
  VALUE request;
  VALUE env;
  std::string host;
  std::string scheme;
  std::string path;
  std::string query;
  std::map<std::string, std::string> headers;
  std::map<std::string, std::string> cookieValues;
};

extern "C" VALUE
parse(VALUE self, VALUE string) {
  Parser parser;
  std::stringstream ss(stdString(string));
  ParseResult result(parser.parse(ss));
  VALUE parsedRules = rb_ary_new2(result.rules.size());

  int index = 0;
  for (const Rule& rule : result.rules) {
    rb_ary_store(parsedRules, index, ruleToHash(rule));
    index++;
  }

  VALUE parsedErrors = rb_hash_new();
  for (const ParseError& error : result.errors) {
    rb_hash_aset(parsedErrors, INT2NUM(error.lnum), rbString(error.line));
  }

  VALUE retval = rb_hash_new();
  rb_hash_aset(retval, ID2SYM(rb_intern("success")), parsedRules);
  rb_hash_aset(retval, ID2SYM(rb_intern("errors")), parsedErrors);
  return retval;
}

extern "C" VALUE
match(VALUE self, VALUE rules, VALUE request, VALUE secret, VALUE roleClaim)
{
  std::vector<Rule> rulesVector;
  long len = RARRAY_LEN(rules);
  for (long i=0; i<len; i++) {
    VALUE el = rb_ary_entry(rules, i);
    VALUE status = rb_hash_aref(el, ID2SYM(rb_intern("status")));
    VALUE force = rb_hash_aref(el, ID2SYM(rb_intern("force")));
    RuleBuilder rule;

    rule.from = stdString(rb_hash_aref(el, ID2SYM(rb_intern("path"))));
    rule.to = stdString(rb_hash_aref(el, ID2SYM(rb_intern("to"))));
    rule.host = stdString(rb_hash_aref(el, ID2SYM(rb_intern("host"))));
    rule.scheme = stdString(rb_hash_aref(el, ID2SYM(rb_intern("scheme"))));
    rule.status = status == Qnil ? 301 : NUM2INT(status);
    rule.force = RTEST(force);

    VALUE rbConditions = rb_hash_aref(el, ID2SYM(rb_intern("conditions")));
    if (rbConditions != Qnil) {
      VALUE keys = rb_funcall(rbConditions, rb_intern("keys"), 0);
      long keyLen = RARRAY_LEN(keys);
      for (long j=0; j<keyLen; j++) {
        VALUE key = rb_ary_entry(keys, j);
        rule.conditions.push_back({stdString(key), stdString(rb_hash_aref(rbConditions, key))});
      }
    }
    VALUE rbParams = rb_hash_aref(el, ID2SYM(rb_intern("params")));
    if (rbParams != Qnil) {
      VALUE keys = rb_funcall(rbParams, rb_intern("keys"), 0);
      long keyLen = RARRAY_LEN(keys);
      for (long j=0; j<keyLen; j++) {
        VALUE key = rb_ary_entry(keys, j);
        rule.params.push_back({stdString(key), stdString(rb_hash_aref(rbParams, key))});
      }
    }

    rule.compile();

    rulesVector.push_back({rule});
  }

  Matcher matcher(rulesVector, stdString(secret), stdString(roleClaim));
  RequestWrapper requestWrapper(request);
  MatchResult result = matcher.match(requestWrapper);

  return resultToMatch(result);
}

extern "C" void
Init_netlify_redirector()
{
  Redirector = rb_const_get(rb_cObject, rb_intern("NetlifyRedirector"));
  rb_define_method(Redirector, "match_rules", (VALUE (*)(...))match, 4);
  rb_define_singleton_method(Redirector, "parse", (VALUE (*)(...))parse, 1);
}
