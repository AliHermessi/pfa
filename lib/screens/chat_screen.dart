import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/intervention.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final Intervention intervention;
  
  const ChatScreen({super.key, required this.intervention});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final isMechanic = _currentUserId == widget.intervention.mecanicienId;
    final recipientId = isMechanic 
        ? widget.intervention.userId 
        : widget.intervention.mecanicienId;
        
    if (recipientId == null || recipientId.isEmpty) return;
    
    final senderName = isMechanic 
        ? (widget.intervention.mecanicienNom ?? "Mécanicien") 
        : "Client";
        
    ChatService.sendMessage(
      interventionId: widget.intervention.id,
      text: text,
      recipientId: recipientId,
      senderName: senderName,
      vehiculeNom: widget.intervention.vehiculeNom,
    );
    _messageController.clear();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isMechanic = _currentUserId == widget.intervention.mecanicienId;
    final otherPersonName = isMechanic 
        ? "Client" 
        : (widget.intervention.mecanicienNom ?? "Mécanicien");

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat avec $otherPersonName', style: const TextStyle(fontSize: 16, color: Colors.white)),
            Text(widget.intervention.vehiculeNom, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.getMessagesStream(widget.intervention.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Erreur: ${snapshot.error}", 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)
                    )
                  );
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      "Aucun message pour le moment\nEnvoyez un message pour commencer la discussion", 
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)
                    )
                  );
                }

                return ListView.builder(
                  reverse: true, // Les messages récents sont en bas
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF1976D2) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          border: isMe ? null : Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(msg.timestamp),
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Zone de saisie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Saisissez un message...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1976D2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
