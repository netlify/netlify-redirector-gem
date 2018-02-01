#include <vector>
#include <sstream>
#include <map>
#include "rule.h"

#ifndef PARSER_H_
#define PARSER_H_

class ParseError
{
public:
  ParseError(std::string msg, std::string line, int lnum);
  std::string msg;
  std::string line;
  int lnum;
};

class ParseResult
{
public:
  ParseResult(std::vector<Rule> rules, std::vector<ParseError> errors);
  std::vector<Rule> rules;
  std::vector<ParseError> errors;
};

class Parser
{
public:
   ParseResult parse(std::stringstream &rules);
};

#endif
