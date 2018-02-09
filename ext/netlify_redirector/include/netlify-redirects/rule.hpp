#include <string>
#include <map>
#include <vector>
#include <iostream>
#include <memory>
#include "request.hpp"

#ifndef RULE_H_
#define RULE_H_

namespace re2 {
  class RE2;
}

using namespace std;

enum ConditionResult { conditionMiss, conditionMatch, condition404 };
enum ConditionType { conditionLanguage, conditionCountry, conditionRole, conditionUnknown };

struct Param
{
  const string key;
  const string value;
};

class Condition
{
public:
  Condition(const string key, const string value);
  Condition(Condition&& c) = default;

  ConditionResult match(Request &request, const string &secret, const string &roleClaim) const;

  const string key;
  const string value;
private:
  ConditionResult matchesLanguage(Request &request) const;
  ConditionResult matchesCountry(Request &request) const;
  ConditionResult matchesRole(Request &request, const string &secret, const string &roleClaim) const;

  const ConditionType type;
};

class SigningPayload
{
public:
  SigningPayload(
      const string secret,
      const string jwtSecret,
      const string type,
      const string header,
      int expiresIn,
      map<string, string> extraFields
  );
  SigningPayload(SigningPayload&& sp) = default;

  const string secret;
  const string jwtSecret;
  const string type;
  const string header;
  int expiresIn;
  const map<string, string> extraFields;
};

class RuleBuilder
{
public:
  RuleBuilder();
  RuleBuilder(RuleBuilder&& rb) = default;

  void compile();

  string from;
  string to;
  string host;
  string scheme;
  string result;
  int status;
  bool valid;
  bool force;
  bool hasSplat;
  bool force404;
  vector<Param> params;
  vector<Condition> conditions;

  std::shared_ptr<std::map<std::string, std::string>> proxyHeaders;
  std::shared_ptr<SigningPayload> signer;

  std::shared_ptr<re2::RE2> regexp;
  std::shared_ptr<std::vector<string>> captures;
private:
  void addCapture(const string &key);
};

class RuleMatch
{
public:
  RuleMatch(const string result, const bool negative);
  RuleMatch(RuleMatch&& m) = default;

  const string result;
  const bool negative;
};

class Rule
{
public:
  Rule(RuleBuilder &builder);
  Rule(Rule&& r) = default;

  bool isProxy() const;
  bool hasConditions() const;
  bool hasParams() const;
  ConditionResult matchConditions(Request &request, const string &secret, const string &roleClaim) const;
  bool testParams(Request &request, string &result) const;
  bool forceMatch() const;
  RuleMatch match(Request &request) const;

  const string from;
  const string to;
  const string host;
  const string scheme;
  const int status;
  const bool force;
  const bool hasSplat;
  const bool force404;
  const vector<Param> params;
  vector<Condition> conditions;
  const std::shared_ptr<re2::RE2> regexp;
  const std::shared_ptr<std::vector<string>> captures;
  const std::shared_ptr<std::map<std::string, std::string>> proxyHeaders;
  const std::shared_ptr<SigningPayload> signer;
  const int capturesSize;

private:
  bool matchCaptures(Request &request, string *result) const;
  bool matchPath(Request &request) const;
  bool testNegativeMatch(Request &request, const string &result) const;
};


#endif
