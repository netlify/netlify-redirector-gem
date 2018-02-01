#include <string>
#include <map>

#ifndef REQUEST_H_
#define REQUEST_H_

class Request
{
public:
  virtual const std::string getHost() = 0;
  virtual const std::string getScheme() = 0;
  virtual const std::string getPath() = 0;
  virtual const std::string getQuery() = 0;
  virtual const std::string getHeader(const std::string &name) = 0;
  virtual const std::string getCookieValue(const std::string &key) = 0;
};

class BasicRequest : public Request
{
public:
  BasicRequest(
    std::string scheme,
    std::string host,
    std::string path,
    std::string query,
    std::map<std::string, std::string> headers,
    std::map<std::string, std::string> cookieValues
  );
  const std::string getHost();
  const std::string getScheme();
  const std::string getPath();
  const std::string getQuery();
  const std::string getHeader(const std::string &name);
  const std::string getCookieValue(const std::string &key);
private:
  std::string scheme;
  std::string host;
  std::string path;
  std::string query;
  std::map<std::string, std::string> headers;
  std::map<std::string, std::string> cookieValues;
};

#endif
