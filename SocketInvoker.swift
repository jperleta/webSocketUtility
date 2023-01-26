import Foundation

protocol WebSocketConnection {
    /// Opening web socket connection
    func connect()
    
    /// Closing web socket connection
    func disconnect()
    
    /// For sending a message of type String
    func send(text: String)
    
    /// For sending a message of type Data
    func send(data: Data)
}

protocol WebSocketConnectionDelegate: AnyObject {
    /// On connection opened
    func onConnected(connection: WebSocketConnection)
    
    /// On connection closed
    func onDisconnected(connection: WebSocketConnection, error: Error?)
    
    /// On error received
    func onError(connection: WebSocketConnection, error: Error)
    
    /// On String message received
    func onMessage(connection: WebSocketConnection, text: String)
    
    /// On Data message recived
    func onMessage(connection: WebSocketConnection, data: Data)
}

class SocketInvoker: NSObject, WebSocketConnection {
    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private weak var delegate: WebSocketConnectionDelegate?
    
    init(url: URL, delegate: WebSocketConnectionDelegate) {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        self.webSocketTask = session?.webSocketTask(with: url)
        self.delegate = delegate
    }
    
    func connect() {
        webSocketTask?.resume()
        
        Task {
            await listen()
            keepConnectionLive()
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    func send(text: String) {
        webSocketTask?.send(URLSessionWebSocketTask.Message.string(text)) { error in
            if let error = error {
                self.delegate?.onError(connection: self, error: error)
            }
        }
    }
    
    func send(data: Data) {
        webSocketTask?.send(URLSessionWebSocketTask.Message.data(data)) { error in
            if let error = error {
                self.delegate?.onError(connection: self, error: error)
            }
        }
    }
    
    /// Receive method is only called once. If we want to receive another message, we need to call receive again.
    private func listen() async {
        guard webSocketTask?.closeCode == .invalid else { return }
        
        do {
            let message = try await webSocketTask?.receive()
            
            switch message {
            case .string(let text):
                delegate?.onMessage(connection: self, text: text)
            case .data(let data):
                delegate?.onMessage(connection: self, data: data)
            @unknown default:
                break
            }
            
            await listen()
        } catch {
            self.delegate?.onError(connection: self, error: error)
        }
    }
    
    /// To avoid that server drops connection we use special ping-pong messages. We should send them periodically (approximately every 10 seconds) to make sure the connection won't get killed by the server.
    private func keepConnectionLive() {
        webSocketTask?.sendPing { (error) in
            if let error = error {
                print("Sending PING failed: \(error)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.keepConnectionLive()
            }
        }
    }
}

extension SocketInvoker: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.delegate?.onConnected(connection: self)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.delegate?.onDisconnected(connection: self, error: nil)
    }
}
