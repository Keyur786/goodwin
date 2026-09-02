import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

class CustomerBulkQuotesScreen extends StatelessWidget {
  const CustomerBulkQuotesScreen({super.key, required this.userId, this.userName = ''});
  final String userId;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Bulk Quotes'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreProductRepository().streamMyBulkInquiries(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load inquiries.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                ),
              ),
            );
          }
          final inquiries = snapshot.data ?? [];
          if (inquiries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(LucideIcons.messageSquare, size: 48, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 16),
                  const Text('No bulk quotes yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  const Text('Submit a bulk inquiry from the home screen\nto get wholesale pricing.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: inquiries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final inq = inquiries[index];
              return _CustomerInquiryCard(
                inquiry: inq,
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _CustomerQuoteChatScreen(inquiry: inq, userId: userId, userName: userName))),
              );
            },
          );
        },
      ),
    );
  }
}

class _CustomerInquiryCard extends StatelessWidget {
  const _CustomerInquiryCard({required this.inquiry, required this.onTap});
  final Map<String, dynamic> inquiry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = inquiry['status'] as String? ?? 'pending';
    final unread = inquiry['unreadByUser'] as bool? ?? false;
    final preview = inquiry['lastMessagePreview'] as String? ?? '';
    final lastMsgAt = inquiry['lastMessageAt'];
    String timeStr = '';
    if (lastMsgAt is Timestamp) {
      final dt = lastMsgAt.toDate();
      final now = DateTime.now();
      if (now.difference(dt).inDays == 0) {
        timeStr = DateFormat('hh:mm a').format(dt);
      } else if (now.difference(dt).inDays == 1) {
        timeStr = 'Yesterday';
      } else {
        timeStr = DateFormat('d MMM').format(dt);
      }
    }
    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'replied':
        statusColor = const Color(0xFF16A34A); statusBg = const Color(0xFFDCFCE7); statusLabel = 'REPLIED'; statusIcon = LucideIcons.checkCircle;
      case 'closed':
        statusColor = const Color(0xFF64748B); statusBg = const Color(0xFFF1F5F9); statusLabel = 'CLOSED'; statusIcon = LucideIcons.lock;
      default:
        statusColor = const Color(0xFFD97706); statusBg = const Color(0xFFFEF3C7); statusLabel = 'PENDING'; statusIcon = LucideIcons.clock;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: unread ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0), width: unread ? 1.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inquiry['categoryOrProduct'] as String? ?? 'Bulk Inquiry',
                          style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty) Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(inquiry['quantityRange'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          unread ? '🔵 New reply from Goodwin Admin' : preview,
                          style: TextStyle(fontSize: 12.5, color: unread ? const Color(0xFF2563EB) : const Color(0xFF64748B), fontWeight: unread ? FontWeight.w700 : FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronRight, color: Color(0xFFCBD5E1), size: 18),
          ],
        ),
      ),
    );
  }
}

class _CustomerQuoteChatScreen extends StatefulWidget {
  const _CustomerQuoteChatScreen({required this.inquiry, required this.userId, required this.userName});
  final Map<String, dynamic> inquiry;
  final String userId;
  final String userName;
  @override
  State<_CustomerQuoteChatScreen> createState() => _CustomerQuoteChatScreenState();
}

class _CustomerQuoteChatScreenState extends State<_CustomerQuoteChatScreen> {
  final _repo = FirestoreProductRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  bool get _isClosed => (widget.inquiry['status'] as String? ?? '') == 'closed';

  @override
  void initState() {
    super.initState();
    _repo.markInquiryReadByUser(widget.inquiry['id'] as String);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textController.clear();
    try {
      await _repo.sendInquiryMessage(
        inquiryId: widget.inquiry['id'] as String,
        senderId: widget.userId,
        senderName: widget.userName.isNotEmpty ? widget.userName : 'Customer',
        text: text,
        isAdmin: false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inq = widget.inquiry;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(inq['categoryOrProduct'] as String? ?? 'Bulk Quote', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const Text('Goodwin Wholesale Team', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            color: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 16, runSpacing: 4,
              children: [
                _SummaryChip(label: '📦 Product', value: inq['categoryOrProduct'] as String? ?? '—'),
                _SummaryChip(label: '🔢 Qty', value: inq['quantityRange'] as String? ?? '—'),
                if (_isClosed) _SummaryChip(label: '🔒', value: 'This inquiry has been closed by admin'),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _repo.streamInquiryMessages(inq['id'] as String),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(LucideIcons.messageSquare, size: 40, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 12),
                        Text('Your inquiry has been submitted.\nOur team will reply shortly.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMine = msg['senderId'] != 'admin';
                    return _CustomerChatBubble(message: msg, isSentByMe: isMine);
                  },
                );
              },
            ),
          ),

          _ComposeBar(
            controller: _textController,
            sending: _sending,
            disabled: _isClosed,
            onSend: _send,
            placeholder: _isClosed ? 'This inquiry is closed' : 'Send a message to our wholesale team…',
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return RichText(text: TextSpan(style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: value)]));
  }
}

class _CustomerChatBubble extends StatelessWidget {
  const _CustomerChatBubble({required this.message, required this.isSentByMe});
  final Map<String, dynamic> message;
  final bool isSentByMe;
  @override
  Widget build(BuildContext context) {
    final sentAt = message['sentAt'];
    String timeStr = '';
    if (sentAt is Timestamp) timeStr = DateFormat('hh:mm a').format(sentAt.toDate());
    final isAdminMsg = message['senderId'] == 'admin';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe) ...[
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(8)),
              child: const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSentByMe ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isSentByMe ? 16 : 4),
                  bottomRight: Radius.circular(isSentByMe ? 4 : 16),
                ),
                border: isSentByMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    isAdminMsg ? '🛡️ Goodwin Admin' : (message['senderName'] as String? ?? 'You'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSentByMe ? Colors.white70 : const Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 3),
                  Text(message['text'] as String? ?? '', style: TextStyle(fontSize: 14, color: isSentByMe ? Colors.white : const Color(0xFF0F172A), height: 1.4)),
                  const SizedBox(height: 4),
                  Text(timeStr, style: TextStyle(fontSize: 10, color: isSentByMe ? Colors.white60 : const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
          if (isSentByMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
              child: const Icon(LucideIcons.user, color: Color(0xFF2563EB), size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  const _ComposeBar({required this.controller, required this.sending, required this.disabled, required this.onSend, required this.placeholder});
  final TextEditingController controller;
  final bool sending;
  final bool disabled;
  final VoidCallback onSend;
  final String placeholder;
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !disabled,
              maxLines: 4, minLines: 1,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                filled: true, fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 46, width: 46,
            decoration: BoxDecoration(color: disabled ? const Color(0xFFCBD5E1) : const Color(0xFF2563EB), borderRadius: BorderRadius.circular(14)),
            child: IconButton(
              onPressed: disabled ? null : (sending ? null : onSend),
              icon: sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(LucideIcons.sendHorizontal, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
