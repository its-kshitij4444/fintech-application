<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    String username = (String) session.getAttribute("username");
    if (username == null) username = "User";
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Stock Chat Assistant</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Poppins', sans-serif; }

        body {
            display: flex;
            height: 100vh;
            background: #f5f6fa;
            color: #333;
        }

        .sidebar {
            width: 250px;
            background: #1e1e2f;
            color: #fff;
            display: flex;
            flex-direction: column;
            padding: 20px;
        }

        .sidebar h2 {
            text-align: center;
            margin-bottom: 30px;
            font-size: 22px;
        }

        .sidebar a {
            color: #bbb;
            text-decoration: none;
            padding: 12px 15px;
            border-radius: 8px;
            margin-bottom: 10px;
            transition: 0.3s;
        }

        .sidebar a:hover, .sidebar a.active {
            background: #4b4b6e;
            color: #fff;
        }

        .main-content {
            flex: 1;
            display: flex;
            flex-direction: column;
            background: #fff;
        }

        .chat-header {
            background: #4b4b6e;
            color: #fff;
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 6px rgba(0,0,0,0.1);
        }

        .chat-header h1 {
            font-size: 24px;
            margin: 0;
        }

        .chat-container {
            flex: 1;
            overflow-y: auto;
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 15px;
        }

		 .message {
		    display: flex;
		    flex-direction: column;
		    margin-bottom: 10px;
		}

        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

		.message.user {
		    align-items: flex-end;
		}
		
		.message.ai {
		    align-items: flex-start;
		}

		.message-content {
		    display: inline-block;
		
		    max-width: 70%;
		    width: fit-content;      /* key */
		    min-width: 80px;         /* prevents tiny bubbles */
		
		    padding: 12px 16px;
		    border-radius: 12px;
		
		    line-height: 1.5;
		    white-space: normal;
		
		    overflow-wrap: break-word;
		    word-break: normal;      /* important */
		}

        .message.user .message-content {
            background: #4b4b6e;
            color: #fff;
            border-radius: 12px 12px 0 12px;
            min-width: 80px;
            width: fit-content;
            display: inline-block;
            text-align: left;
            word-break: normal;
            overflow-wrap: break-word;
        }

        .message.ai .message-content {
            background: #e8e8f0;
            color: #333;
            border-radius: 12px 12px 12px 0;
            min-width: 60px;
            word-break: normal;
            overflow-wrap: break-word;
            line-height: 1.8;
            white-space: normal;
        }
        
       
		.message-timestamp {
		    font-size: 12px;
		    color: #999;
		    margin-top: 4px;
		}
		
		.message.user .message-timestamp {
		    text-align: right;
		}
		
		.message.ai .message-timestamp {
		    text-align: left;
		}

        .chat-input-section {
            padding: 20px;
            background: #fff;
            border-top: 1px solid #eee;
            display: flex;
            gap: 10px;
        }

        .chat-input-section input {
            flex: 1;
            padding: 12px 16px;
            border: 1px solid #ddd;
            border-radius: 8px;
            font-size: 14px;
            outline: none;
            transition: 0.3s;
        }

        .chat-input-section input:focus {
            border-color: #4b4b6e;
            box-shadow: 0 0 5px rgba(75, 75, 110, 0.2);
        }

        .chat-input-section button {
            padding: 12px 24px;
            background: #4b4b6e;
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            cursor: pointer;
            transition: 0.3s;
            font-weight: 600;
        }

        .chat-input-section button:hover {
            background: #3a3a52;
        }

        .chat-input-section button:disabled {
            background: #ccc;
            cursor: not-allowed;
        }

        .typing-indicator {
            display: flex;
            flex-direction: row;
            gap: 4px;
            padding: 12px 16px;
            background: #e8e8f0;
            border-radius: 12px;
            width: fit-content;
            align-items: center;
        }

        .typing-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #999;
            animation: typing 1.4s infinite;
        }

        .typing-dot:nth-child(2) {
            animation-delay: 0.2s;
        }

        .typing-dot:nth-child(3) {
            animation-delay: 0.4s;
        }

        @keyframes typing {
            0%, 60%, 100% { transform: translateY(0); opacity: 0.5; }
            30% { transform: translateY(-10px); opacity: 1; }
        }

        @media(max-width: 900px) {
            .sidebar { width: 100%; }
            .main-content { height: auto; }
            .message-content { max-width: 85%; }
        }
    </style>
</head>
<body>

    <div class="sidebar">
        <a href="dashboard.jsp">Dashboard</a>
        <a href="index.jsp">Search Stocks</a>
        <a href="paperTrading.jsp">Practice Trading</a>
        <a href="profile.jsp">Profile</a>
        <a href="TradeHistory.jsp">Trade History</a>
        <a href="chat.jsp" class="active">Chat Assistant</a>
        <a href="settings.jsp">Settings</a>
        <form action="LogoutServlet" method="post" style="margin-top: auto;">
            <button type="submit" style="width:100%; padding:12px; background:#dc3545; color:#fff; border:none; border-radius:8px; cursor:pointer; font-weight:600;">Logout</button>
        </form>
    </div>

    <div class="main-content">
        <div class="chat-header">
            <h1>💬 Stock Chat Assistant</h1>
            <p style="margin-top: 5px; font-size: 14px; opacity: 0.9;">Ask me anything about stocks and trading</p>
            
            <div style="margin-top:10px; display:flex; justify-content:center; align-items:center; gap:10px;">
			    <label style="font-size:13px; opacity:0.85;">🤖 Model:</label>
			    <select id="modelSelect"
			            style="padding:6px 12px; border-radius:8px; border:none; font-size:13px;
			                   background:#5c5c8a; color:#fff; cursor:pointer; outline:none;">
			        <option value="qwen/qwen3-32b">Qwen3 32B — Best Reasoning</option>
			        <option value="moonshotai/kimi-k2-instruct">Kimi K2 — Most Tokens</option>
			        <option value="llama-3.3-70b-versatile">Llama 3.3 70B — Versatile</option>
			        <option value="llama-3.1-8b-instant">Llama 3.1 8B — Fastest ⚡</option>
			    </select>
			</div>
        </div>

        <div class="chat-container" id="chatContainer">
            <div class="message ai">
                <div>
                    <div class="message-content">
                        👋 Hi <%= username %>! I'm your stock trading assistant. Ask me anything about stocks, market trends, or trading strategies!
                    </div>
                    <div class="message-timestamp">Just now</div>
                </div>
            </div>
        </div>

        <div class="chat-input-section">
            <input 
                type="text" 
                id="messageInput" 
                placeholder="Ask about stocks, prices, trading tips..." 
                onkeypress="handleKeyPress(event)"
            />
            <button onclick="sendMessage()" id="sendBtn">Send</button>
        </div>
    </div>

    <script>
        const chatContainer = document.getElementById('chatContainer');
        const messageInput = document.getElementById('messageInput');
        const sendBtn = document.getElementById('sendBtn');

        function formatTime(ts) {
            if (!ts) {
                const now = new Date();
                return now.toLocaleTimeString('en-US', {
                    hour: '2-digit',
                    minute: '2-digit',
                    hour12: true
                });
            }
            const d = new Date(ts);
            return d.toLocaleTimeString('en-US', {
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            });
        }

        function escapeHtml(text) {
            return text
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;");
        }

        function addMessage(text, isUser, ts = null, clearWelcome = false) {
            if (clearWelcome) {
                chatContainer.innerHTML = '';
            }

            const messageDiv = document.createElement('div');
            messageDiv.className = 'message ' + (isUser ? 'user' : 'ai');

            let formattedText = escapeHtml(text);
            if (!isUser) {
                formattedText = formattedText
                    .replace(/\n/g, "<br>")
                    .replace(/━+/g, '<hr style="border:none;border-top:1px solid #ccc;margin:6px 0;">');
            }

            messageDiv.innerHTML =
                '<div>' +
                '<div class="message-content">' + formattedText + '</div>' +
                '<div class="message-timestamp">' + formatTime(ts) + '</div>' +
                '</div>';

            chatContainer.appendChild(messageDiv);
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }

        function showTypingIndicator() {
            const messageDiv = document.createElement('div');
            messageDiv.className = 'message ai';
            messageDiv.id = 'typingIndicator';

            messageDiv.innerHTML =
                '<div class="typing-indicator">' +
                '<div class="typing-dot"></div>' +
                '<div class="typing-dot"></div>' +
                '<div class="typing-dot"></div>' +
                '</div>';

            chatContainer.appendChild(messageDiv);
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }

        function removeTypingIndicator() {
            const indicator = document.getElementById('typingIndicator');
            if (indicator) indicator.remove();
        }

        async function loadChatHistory() {
            try {
                const response = await fetch('ChatServlet');
                const data = await response.json();

                if (data.history && data.history.length > 0) {
                    chatContainer.innerHTML = '';
                    data.history.forEach(msg => {
                        addMessage(msg.content, msg.role === 'user', msg.timestamp);
                    });
                }
            } catch (e) {
                console.error('History load failed:', e);
            }
        }

        async function sendMessage() {
            const message = messageInput.value.trim();
            if (!message) return;

            addMessage(message, true);
            messageInput.value = '';
            sendBtn.disabled = true;
            showTypingIndicator();

            try {
                const response = await fetch('ChatServlet', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: 'message=' + encodeURIComponent(message)
                        + '&model=' + encodeURIComponent(document.getElementById('modelSelect').value)
                });

                const data = await response.json();
                removeTypingIndicator();

                if (data.reply) {
                    addMessage(data.reply, false);
                } else if (data.error) {
                    addMessage('❌ Error: ' + data.error, false);
                } else {
                    addMessage('Sorry, I couldn\'t process that. Please try again.', false);
                }
            } catch (e) {
                removeTypingIndicator();
                console.error('Chat error:', e);
                addMessage('❌ Connection error. Please try again.', false);
            }

            sendBtn.disabled = false;
            messageInput.focus();
        }

        function handleKeyPress(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        }

        loadChatHistory();
        messageInput.focus();
    </script>

</body>
</html>
