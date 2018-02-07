#include <vector>
#include <sstream>
#include <map>
#include "rule.hpp"

#ifndef PARSER_H_
#define PARSER_H_

class ParseError
{
public:
  ParseError(const std::string msg, const std::string line, int lnum);
  ParseError(ParseError&& e) = default;
  const std::string msg;
  const std::string line;
  int lnum;
};

class ParseResult
{
public:
  ParseResult(std::vector<Rule> rules, std::vector<ParseError> errors);
  ParseResult(ParseResult&& r) = default;
  std::vector<Rule> rules;
  std::vector<ParseError> errors;
};

class Parser
{
public:
   ParseResult parse(std::stringstream &rules);
   ParseResult parseJSON(std::stringstream &rules);
};

#endif
