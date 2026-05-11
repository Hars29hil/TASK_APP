import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  final TextEditingController messageController =
      TextEditingController();

  // TEMP MESSAGE LIST
  List<Map<String, dynamic>> messages = [
    {
      "message": "Hello 👋",
      "isMe": false,
    },
    {
      "message": "Hi 🔥",
      "isMe": true,
    },
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xffEEF5FF),

      body: SafeArea(

        child: Column(

          children: [

            // =========================
            // TOP HEADER
            // =========================

            Container(

              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 12,
              ),

              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black.withValues(alpha: 0.05),
                  )
                ],
              ),

              child: Row(

                children: [

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_ios),
                  ),

                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xffD9D9FF),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Text(
                          "Harshil Patel",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 2),

                        Row(
                          children: [

                            CircleAvatar(
                              radius: 4,
                              backgroundColor: Colors.green,
                            ),

                            SizedBox(width: 5),

                            Text(
                              "Online",
                              style: TextStyle(
                                color: Colors.green,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),

            // =========================
            // CHAT LIST
            // =========================

            Expanded(

              child: ListView.builder(

                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),

                itemCount: messages.length,

                itemBuilder: (context, index) {

                  final message = messages[index];

                  return Align(

                    alignment: message["isMe"]
                        ? Alignment.centerRight
                        : Alignment.centerLeft,

                    child: Container(

                      margin: const EdgeInsets.only(bottom: 12),

                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),

                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width *
                                0.75,
                      ),

                      decoration: BoxDecoration(

                        gradient: message["isMe"]
                            ? const LinearGradient(
                                colors: [
                                  Color(0xff7B61FF),
                                  Color(0xff5B3FFF),
                                ],
                              )
                            : null,

                        color: message["isMe"]
                            ? null
                            : Colors.white,

                        borderRadius: BorderRadius.circular(20),

                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            color: Colors.black.withValues(alpha: 0.05),
                          )
                        ],
                      ),

                      child: Text(

                        message["message"],

                        style: TextStyle(
                          color: message["isMe"]
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // =========================
            // INPUT BAR
            // =========================

            Container(

              padding: const EdgeInsets.all(12),

              color: Colors.transparent,

              child: Row(

                children: [

                  // ADD BUTTON

                  Container(

                    height: 55,
                    width: 55,

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),

                    child: const Icon(
                      Icons.add,
                      color: Colors.deepPurple,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // INPUT FIELD

                  Expanded(

                    child: Container(

                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),

                      height: 58,

                      decoration: BoxDecoration(

                        color: Colors.white,

                        borderRadius:
                            BorderRadius.circular(30),

                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            color: Colors.black.withValues(alpha: 0.04),
                          )
                        ],
                      ),

                      child: Row(

                        children: [

                          Expanded(

                            child: TextField(

                              controller: messageController,

                              decoration:
                                  const InputDecoration(
                                border: InputBorder.none,
                                hintText:
                                    "Type a message...",
                              ),
                            ),
                          ),

                          const Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // MIC BUTTON

                  Container(

                    height: 58,
                    width: 58,

                    decoration: const BoxDecoration(

                      shape: BoxShape.circle,

                      gradient: LinearGradient(
                        colors: [
                          Color(0xff7B61FF),
                          Color(0xff5B3FFF),
                        ],
                      ),
                    ),

                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
