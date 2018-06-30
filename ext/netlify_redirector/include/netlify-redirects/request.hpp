#include <string>
#include <map>

#ifndef REQUEST_H_
#define REQUEST_H_

class Request
{
public:
	virtual std::string getHost() = 0;
	virtual std::string getScheme() = 0;
	virtual std::string getPath() = 0;
	virtual std::string getQuery() = 0;
	virtual std::string getHeader(const std::string &name) = 0;
	virtual std::string getCookieValue(const std::string &key) = 0;
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
	std::string getHost();
	std::string getScheme();
	std::string getPath();
	std::string getQuery();
	std::string getHeader(const std::string &name);
	std::string getCookieValue(const std::string &key);
private:
	std::string scheme;
	std::string host;
	std::string path;
	std::string query;
	std::map<std::string, std::string> headers;
	std::map<std::string, std::string> cookieValues;
};

#endif
