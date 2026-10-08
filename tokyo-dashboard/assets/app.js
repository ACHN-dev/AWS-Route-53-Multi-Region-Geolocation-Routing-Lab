/**
 * Dashboard Client (Pure Vanilla JS - No external dependencies)
 */

var socket = io({ transports: ["websocket"] });

function updateStatus(text, className) {
  var el = document.getElementById("connection-status");
  if (el) {
    el.className = className || "";
    el.textContent = text;
  }
}

function disconnected(message) {
  updateStatus("Disconnected", "disconnected");
}

function disconnectedFromBackendService(message) {
  updateStatus("Counting Service is Unreachable", "disconnected");
}

function didConnect() {
  updateStatus("Connected", "connected");
}

socket.on("disconnect", disconnected);
socket.on("connect_error", disconnected);
socket.on("connect_timeout", disconnected);
socket.on("error", disconnected);
socket.on("reconnect_error", disconnected);
socket.on("reconnect_failed", disconnected);
socket.on("reconnect_attempt", disconnected);
socket.on("reconnecting", disconnected);

// Listen for messages from server
socket.on("message", function(message) {
  if (!message) return;

  if (message.count < 0) {
    disconnectedFromBackendService();
  } else {
    didConnect();
  }

  var countEl = document.getElementById("count");
  if (countEl && message.count !== undefined) {
    countEl.textContent = Number(message.count).toLocaleString();
  }

  var hostEl = document.getElementById("hostname");
  if (hostEl && message.hostname) {
    hostEl.textContent = message.hostname;
  }
});

socket.on("connect", function() {
  didConnect();

  function broadcastMessage() {
    socket.emit("send", { "message": "get count" });
    setTimeout(broadcastMessage, 1000); // 1 second interval (calm & steady)
  }
  broadcastMessage();
});
