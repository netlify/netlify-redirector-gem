#include <vector>
#include <set>
#include <memory>
#include "rule.hpp"
#include "request.hpp"

#ifndef MATCHER_H_
#define MATCHER_H_

class Match
{
public:
  Match(const Rule &rule, const std::string &match);

  const std::string from;
  const std::string to;
  const std::string host;
  const std::string scheme;
  const int status;
  const bool force;
  const bool forceMatch;

  const std::shared_ptr<std::map<std::string, std::string>> proxyHeaders;
  const std::shared_ptr<SigningPayload> signer;
};

class MatchResult
{
public:
  MatchResult(const std::string &roleClaim);
  const bool isMatch() const { return match != nullptr; }
  const char * getCondition(string key) const;
  const char * getException(string key) const;

  std::unique_ptr<Match> match;
  std::map<std::string, std::set<std::string>> conditions;
  std::map<std::string, std::set<std::string>> exceptions;
  bool force404;
private:
  const std::string &roleClaim;
};

class Matcher
{
public:
  Matcher(const std::vector<Rule> &rules, const std::string secret, const std::string roleClaim);
  MatchResult match(Request &request);
private:
  void setHeaders(const vector<Condition> &conditions, std::map<std::string, std::set<std::string>> &headers);
  const std::vector<Rule> &rules;
  const std::string secret;
  const std::string roleClaim;
};

#endif
