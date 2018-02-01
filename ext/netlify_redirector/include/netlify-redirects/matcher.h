#include <vector>
#include <set>
#include <memory>
#include "rule.h"
#include "request.h"

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
};

class MatchResult
{
public:
  bool isMatch() const { return match != nullptr; }

  std::unique_ptr<Match> match;
  std::map<std::string, std::set<std::string>> conditions;
  std::map<std::string, std::set<std::string>> exceptions;
  bool force404;
};

class Matcher
{
public:
  Matcher(const std::vector<Rule> &rules, const std::string secret, const std::string roleClaim);
  MatchResult match(Request &request);
private:
  const std::vector<Rule> &rules;
  const std::string secret;
  const std::string roleClaim;
};

#endif
