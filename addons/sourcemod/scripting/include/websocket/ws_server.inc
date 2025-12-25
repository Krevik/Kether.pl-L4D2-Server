enum AddressFamily {
  IPV4,
  IPV6
}

/**
* Typeset for WebsocketServerCallback
*
* A typeset defining various callback functions for WebSocket server events.
*/
typeset WebsocketServerCallback
{
  /**
  * Function to call when a connection is opened
  *
  * @param server            websocket server handle
  * @param RemoteAddr        remote address of the client
  * @param RemoteId          remote identifier of the client
  */
  function void (WebSocketServer server, const char[] RemoteAddr, const char[] RemoteId);

  /**
  * Function to call when a message is received
  *
  * @param server            websocket server handle
  * @param client            websocket client handle
  * @param message           message received
  * @param wireSize          size of the message on the wire (including null terminator)
  * @param RemoteAddr        remote address of the client
  * @param RemoteId          remote identifier of the client
  */
  function void (WebSocketServer server, WebSocket client, const char[] message, int wireSize, const char[] RemoteAddr, const char[] RemoteId);

  /**
  * Function to call when a connection is closed
  *
  * @param server            websocket server handle
  * @param code              close code
  * @param reason            reason for closure
  * @param RemoteAddr        remote address of the client
  * @param RemoteId          remote identifier of the client
  */
  function void (WebSocketServer server, int code, const char[] reason, const char[] RemoteAddr, const char[] RemoteId);

  /**
  * Function to call when an error occurs
  *
  * @param server            websocket server handle
  * @param errMsg            error message
  * @param RemoteAddr        remote address of the client
  * @param RemoteId          remote identifier of the client
  */
  function void (WebSocketServer server, const char[] errMsg, const char[] RemoteAddr, const char[] RemoteId);
}

/**
* Methodmap for WebSocketServer
*
* A methodmap defining various native methods for a WebSocket server
*/
methodmap WebSocketServer < Handle
{
  /**
  * Create New WebSocket server
  *
  * @note All callbacks need to be set before server startup
  *
  * @param host              host address for the server
  * @param port              port number for the server
  * @param af                address family to use. Defaults to IPV4
  * @param pingInterval      interval seconds at which the server sends ping messages to clients (-1 to disable)
  */
  public native WebSocketServer(const char[] host, int port, AddressFamily af = IPV4, int pingInterval = -1);

  /**
  * Set the callback for when a message is received
  *
  * @param fOnMessage        Function to call when a message is received
  */
  public native void SetMessageCallback(WebsocketServerCallback fOnMessage);

  /**
  * Set the callback for when a connection is opened
  *
  * @param fOnOpen           Function to call when a connection is opened
  */
  public native void SetOpenCallback(WebsocketServerCallback fOnOpen);

  /**
  * Set the callback for when a connection is closed
  *
  * @param fOnClose          Function to call when a connection is closed
  */
  public native void SetCloseCallback(WebsocketServerCallback fOnClose);

  /**
  * Set the callback for when an error occurs
  *
  * @param fOnError          Function to call when an error occurs
  */
  public native void SetErrorCallback(WebsocketServerCallback fOnError);

  /**
  * Broadcast a message to all connected clients
  *
  * @param message           message to broadcast
  */
  public native void BroadcastMessage(const char[] message);

  /**
  * Retrieves the value of a specific HTTP header from a connected WebSocket client.
  *
  * @param clientId          The unique ID of the client.
  * @param headerKey         The name of the HTTP header to retrieve.
  * @param buffer            The buffer to store the retrieved header value.
  * @param maxlength         The maximum number of characters to write to the buffer (including null terminator).
  * @return                  True if the header was found and written to the buffer, false otherwise.
  */
  public native bool GetHeader(const char[] clientId, const char[] headerKey, char[] buffer, int maxlength);

  /**
  * Send a message to the client
  *
  * @param clientId          client id
  * @param message           message to send
  */
  public native bool SendMessageToClient(const char[] clientId, const char[] message);

  /**
  * Forcibly disconnect client from websocket
  *
  * @param clientId          client id
  */
  public native bool DisconnectClient(const char[] clientId);

  /**
  * Gets a client ID by index
  *
  * @param index             Index of the client ID to retrieve
  * @param buffer            String buffer to store the ID
  * @param maxlength         Maximum length of the buffer
  * @return                  true on success, false if index is invalid
  */
  public native bool GetClientIdByIndex(int index, char[] buffer, int maxlength);

  /**
  * Start the WebSocket server
  */
  public native void Start();

  /**
  * Stop the WebSocket server
  */
  public native void Stop();

  /**
  * Retrieve/Set Per-Message Deflate compression
  *
  * @note                    Must be called before Start()
  */
  property bool PerMessageDeflate {
    public native get();
    public native set(bool enable);
  }

  /**
  * Maximum length of client IDs (including null terminator)
  */
  property int MaxClientIdLength {
    public native get();
  }

  /**
  * Retrieves connected clients
  */
  property int ClientsCount {
    public native get();
  }

  /**
  * Retrieve/Set Pong is enabled
  */
  property bool EnablePong {
    public native get();
    public native set(bool enablePong);
  }

  /**
  * Set TLS certificate and key files
  *
  * @param certFile          Path to certificate file
  * @param keyFile           Path to key file
  * @note                    Must be called before Start()
  */
  public native void SetTLSCertAndKey(const char[] certFile, const char[] keyFile);

  /**
  * Set TLS CA file for client certificate verification (mutual TLS)
  *
  * @param caFile            Path to CA file for verifying client certificates
  *                          - "NONE": Don't require client certificates (standard single-way TLS, recommended)
  *                          - "SYSTEM": Verify clients using system CA bundle (default if not called)
  *                          - Path: Custom CA file to verify specific client certificates (enables mTLS)
  * @note                    Must be called before Start()
  * @note                    This verifies CLIENT certificates, not server's own certificate
  * @note                    Default is "SYSTEM" - call SetTLSCAFile("NONE") to allow clients without certificates (like HTTPS)
  */
  public native void SetTLSCAFile(const char[] caFile);

  /**
  * Set TLS ciphers
  *
  * @param ciphers           Cipher list (e.g., "DEFAULT", "rsa", "etc...")
  * @note                    Must be called before Start()
  */
  public native void SetTLSCiphers(const char[] ciphers);

  /**
  * Retrieve/Set whether TLS is enabled
  *
  * @note                    Must be called before Start()
  */
  property bool TLSEnabled {
    public native get();
    public native set(bool enable);
  }

  /**
  * Retrieve/Set hostname validation for client certificates
  *
  * @note                    Must be called before Start()
  * @note                    Usually not useful for servers (client certs typically don't have hostnames)
  * @note                    Only relevant in rare mTLS scenarios with hostname-based client certs
  */
  property bool HostnameValidation {
    public native get();
    public native set(bool enable);
  }

  /**
  * Retrieve/Set the maximum connections allowed per IP address (0 = unlimited)
  *
  * @note                    Must be called before Start()
  */
  property int MaxConnectionsPerIp {
    public native get();
    public native set(int max);
  }

  /**
  * Get the current connection count for a specific IP address
  *
  * @param ip               IP address to check
  * @return                 Number of connections from this IP
  */
  public native int GetConnectionCountForIp(const char[] ip);

  /**
  * Retrieve/Set the ping timeout in seconds
  *
  * Time to wait for a pong response after sending a ping to clients.
  * If no pong is received within this time, the client connection is closed.
  * Set to -1 to disable.
  *
  * @note                    Default: -1 (disabled)
  * @note                    Must be called before Start()
  */
  property int PingTimeout {
    public native get();
    public native set(int secs);
  }

  /**
  * Retrieve/Set the idle timeout in seconds
  *
  * Time allowed without receiving any data messages (TEXT/BINARY) from clients.
  * Ping/pong frames do not reset this timer.
  * If no data is received within this time, the client connection is closed.
  * Set to -1 to disable.
  *
  * @note                    Default: -1 (disabled)
  * @note                    Must be called before Start()
  */
  property int IdleTimeout {
    public native get();
    public native set(int secs);
  }

  /**
  * Retrieve/Set the send timeout in seconds
  *
  * Maximum time allowed for a send operation to complete.
  * If sending takes longer than this, the operation fails.
  *
  * @note                    Default: 300 seconds
  * @note                    Must be called before Start()
  */
  property int SendTimeout {
    public native get();
    public native set(int secs);
  }

  /**
  * Retrieve/Set the close timeout in seconds
  *
  * Time to wait for a clean close handshake to complete.
  * After initiating close, if the client doesn't respond within this time,
  * the connection is forcibly terminated.
  *
  * @note                    Default: 5 seconds
  * @note                    Must be called before Start()
  */
  property int CloseTimeout {
    public native get();
    public native set(int secs);
  }

  /**
  * Add a WebSocket subprotocol
  *
  * @param protocol          Subprotocol name to add
  * @note                    Must be called before Start()
  */
  public native void AddSubProtocol(const char[] protocol);

  /**
  * Remove a WebSocket subprotocol
  *
  * @param protocol          Subprotocol name to remove
  * @note                    Must be called before Start()
  */
  public native void RemoveSubProtocol(const char[] protocol);

  /**
  * Clear all WebSocket subprotocols
  *
  * @note                    Must be called before Start()
  */
  public native void ClearSubProtocols();

  /**
  * Retrieve/Set the handshake timeout in seconds
  *
  * Maximum time allowed for the WebSocket handshake to complete.
  * If the handshake takes longer than this, the connection fails.
  *
  * @note                    Default: 5 seconds
  * @note                    Must be called before Start()
  */
  property int HandshakeTimeout {
    public native get();
    public native set(int timeout);
  }
}