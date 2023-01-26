# WebSocketUtility
Small utility that supports native web socket connection added in iOS 13.

A WebSocket is a network protocol that allows two-way communication between a server and client. Unlike HTTP, which uses a request and response pattern, WebSocket peers can send messages in either direction at any point in time. WebSockets are often used for chat-based apps and other apps that need to continuously talk between server and client.

This utility supports:
- Initiating a WebSocket connection.
- Disconnecting from WebSocket session.
- Sending String or Data messages through the WebSocket.
- Processing received messages sent through the WebSocket.

Note that the resulting code has only had relatively limited testing done.
