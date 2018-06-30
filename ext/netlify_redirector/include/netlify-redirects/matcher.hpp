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
	Match(const Rule &rule, const string &match);
	Match(Match&& m) = default;

	const string from;
	const string to;
	const string host;
	const string scheme;
	const int status;
	const bool force;
	const bool forceMatch;

	const shared_ptr<map<string, string>> proxyHeaders;
	const shared_ptr<SigningPayload> signer;
};

class MatchResult
{
public:
	MatchResult(const string &roleClaim, const map<string, set<string>> conditions, const map<string, set<string>> exceptions, bool force404);
	MatchResult(const string &roleClaim, const map<string, set<string>> conditions, const map<string, set<string>> exceptions, bool force404, const Rule &rule, const string &m);
	MatchResult(MatchResult&& r) = default;
	bool isMatch() const { return match != nullptr; }
	const string getCondition(string key);
	const string getException(string key);

	unique_ptr<Match> match;
	const map<string, set<string>> conditions;
	const map<string, set<string>> exceptions;
	bool force404;
private:
	const string &roleClaim;
};

class Matcher
{
public:
	Matcher(const vector<Rule> &rules, const string secret, const string roleClaim);
	Matcher(Matcher&& m) = default;
	MatchResult match(Request &request);
private:
	void pruneExceptions(const map<string, set<string>> &conditions, map<string, set<string>> &exceptions);
	void setHeaders(const vector<Condition> &conditions, map<string, set<string>> &headers);
	const vector<Rule> &rules;
	const string secret;
	const string roleClaim;
};

#endif
