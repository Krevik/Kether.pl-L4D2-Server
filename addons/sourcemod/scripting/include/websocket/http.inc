// Define a typeset for HTTP response callbacks
typeset ResponseCallback
{
  /**
  * Function called when an HTTP response is received
  *
  * @param http              HTTP request object
  * @param body              Response body
  * @param statusCode        HTTP status code
  * @param bodySize          Size of the response body
  * @param value             Value passed to the HTTP method
  */
  function void (HttpRequest http, const char[] body, int statusCode, int bodySize, any value);
}

methodmap HttpRequest < Handle
{
  /**
  * Create a new HTTP request
  *
  * @param url               Request URL
  */
  public native HttpRequest(const char[] url);

  /**
  * Performs a GET request
  * GET requests should not have a body, only query parameters in URL
  *
  * @param fResponse         Function to call when an HTTP response is received
  * @param value             Value to pass to the callback
  * @return                  True if the request was sent successfully, false otherwise
  */
  public native bool Get(ResponseCallback fResponse, any value = 0);

  /**
  * Performs a POST request with JSON body
  * POST requests typically send data to create a new resource
  *
  * @param json              JSON data to send in request body
  * @param fResponse         Function to call when an HTTP response is received
  * @param value             Value to pass to the callback
  * @return                  True if the request was sent successfully, false otherwise
  */
  public native bool PostJson(const JSON json, ResponseCallback fResponse, any value = 0);

  /**
  * Performs a POST request with accumulated form parameters
  * Uses application/x-www-form-urlencoded format
  *
  * @param fResponse         Function to call when an HTTP response is received
  * @param value             Value to pass to the callback
  * @return                  True if the request was sent successfully, false otherwise
  */
  public native bool PostForm(ResponseCallback fResponse, any value = 0);

  /**
  * Performs a PUT request with JSON body
  * PUT requests typically update an entire resource
  *
  * @param json              JSON data to send in request body
  * @param fResponse         Function to call when an HTTP response is received
  * @param value             Value to pass to the callback
  * @return                  True if the request was sent successfully, false otherwise
  */
  public native bool PutJson(const JSON json, ResponseCallback fResponse, any value = 0);

  /**
  * Performs a PATCH request with JSON body
  * PATCH requests typically perform partial updates to a resource
  *
  * @param json              JSON data containing the fields to update
  * @param fResponse         Function to call when an HTTP response is received
  * @param value             Value to pass to the callback
  * @return                  True if the request was sent successfully, false otherwise
  */
  public native bool PatchJson(const JSON json, ResponseCallback fResponse, any value = 0);

  /**
  * Performs a DELETE request
  * DELETE requests typically don't have a body
  *
  * @param fResponse         Function to call when an HTTP response is received
  * @param value             Value to pass to the callback
  * @return                  True if the request was sent successfully, false otherwise
  */
  public native bool Delete(ResponseCallback fResponse, any value = 0);

  /**
  * Append a form parameter to the request
  * Multiple calls will accumulate parameters for the next form submission
  *
  * @param key               Parameter key
  * @param value             Parameter value
  * @return                  True if parameter was added successfully
  */
  public native bool AppendFormParam(const char[] key, const char[] value);

  /**
  * Add a header to the HTTP request
  *
  * @param key               Header key
  * @param value             Header value
  */
  public native void AddHeader(const char[] key, const char[] value);

  /**
  * Get a response header from the HTTP request
  *
  * @param key               Header key
  * @param value             Buffer to store the header value
  * @param maxLength         Maximum length of the value buffer
  * @return                  True if the header was found, false otherwise
  */
  public native bool GetResponseHeader(const char[] key, char[] value, int maxLength);

  /**
  * Check if a response header exists in the HTTP request
  *
  * @param key               Header key
  * @return                  True if the header exists, false otherwise
  */
  public native bool HasResponseHeader(const char[] key);

  /**
  * Get or set the connection timeout in milliseconds
  *
  * @note                    Default timeout varies by platform
  */
  property int Timeout {
    public native get();
    public native set(int timeout);
  }

  /**
  * Get or set whether to follow HTTP redirects
  *
  * @note                    When enabled, automatically follows 3xx redirect responses
  */
  property bool FollowRedirect {
    public native get();
    public native set(bool follow);
  }

  /**
  * Get or set whether to enable response compression
  *
  * @note                    Supports gzip and deflate compression
  */
  property bool Compression {
    public native get();
    public native set(bool compress);
  }

  /**
  * Get or set the maximum number of redirects to follow
  *
  * @note                    Only applies when FollowRedirect is enabled
  */
  property int MaxRedirects {
    public native get();
    public native set(int maxRedirects);
  }

  /**
  * Get or set verbose mode for debugging
  *
  * @note                    When enabled, prints detailed request/response information
  */
  property bool Verbose {
    public native get();
    public native set(bool verbose);
  }

  /**
  * Set TLS certificate and key files for client authentication
  *
  * @param certFile          Path to certificate file (relative to game directory)
  * @param keyFile           Path to key file (relative to game directory)
  * @note                    Used for mTLS when server requires client certificates
  * @note                    Must be called before making requests
  */
  public native void SetTLSCertAndKey(const char[] certFile, const char[] keyFile);

  /**
  * Set TLS CA file for server certificate verification
  *
  * @param caFile            Path to CA file for verifying server certificates
  *                          - "SYSTEM": Use system CA bundle to verify server (default, recommended)
  *                          - "NONE": Disable server certificate verification (UNSAFE, testing only!)
  *                          - Path: Custom CA file to trust specific server certificates
  * @note                    Must be called before making requests
  * @note                    This verifies the SERVER's identity when connecting via HTTPS
  */
  public native void SetTLSCAFile(const char[] caFile);

  /**
  * Set TLS ciphers
  *
  * @param ciphers           Cipher list (e.g., "DEFAULT", "rsa ...")
  * @note                    Must be called before making requests
  */
  public native void SetTLSCiphers(const char[] ciphers);

  /**
  * Get or set hostname validation for server certificates
  *
  * @note                    Must be called before making requests
  * @note                    When true, verifies server certificate hostname matches the request URL
  * @note                    Recommended: keep enabled (default) to prevent MITM attacks
  */
  property bool HostnameValidation {
    public native get();
    public native set(bool enable);
  }

  /**
  * Get or set HTTP Keep-Alive
  *
  * @note                    When enabled, reuses TCP connections for multiple requests
  * @note                    Default: enabled
  */
  property bool KeepAlive {
    public native get();
    public native set(bool enable);
  }

  /**
  * Get or set whether to use connection pooling
  *
  * @note                    When enabled, connections are pooled and reused across requests
  */
  property bool UseConnectionPool {
    public native get();
    public native set(bool enable);
  }

  /**
  * Set proxy for HTTP requests
  *
  * @param proxyUrl          Proxy URL (e.g., "http://proxy:8080", "socks5://proxy:1080")
  * @note                    Supports HTTP, HTTPS, and SOCKS5 proxies
  */
  public native void SetProxy(const char[] proxyUrl);

  /**
  * Clear proxy configuration
  */
  public native void ClearProxy();

  /**
  * Check if proxy is configured
  */
  property bool HasProxy {
    public native get();
  }

  /**
  * Set HTTP Basic authentication
  *
  * @param username         Username for authentication
  * @param password         Password for authentication
  */
  public native void SetBasicAuth(const char[] username, const char[] password);

  /**
  * Set HTTP Bearer token authentication
  *
  * @param token            Bearer token for authentication
  */
  public native void SetBearerAuth(const char[] token);

  /**
  * Clear authentication configuration
  */
  public native void ClearAuth();
}
