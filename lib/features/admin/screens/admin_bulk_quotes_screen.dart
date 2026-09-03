import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/utils/image_upload_helper.dart';
import 'package:goodwin/shared/widgets/full_screen_image_viewer.dart';
import 'package:goodwin/shared/widgets/product_image_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

class AdminBulkQuotesScreen extends StatelessWidget {
  const AdminBulkQuotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bulk Quote Requests'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreProductRepository().streamAllBulkInquiries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final inquiries = snapshot.data ?? [];
          if (inquiries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(LucideIcons.messageSquare, size: 48, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 16),
                  const Text('No bulk quote requests yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  const Text('When customers submit inquiries,\nthey will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
              return _InquiryCard(
                inquiry: inq,
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _AdminQuoteChatScreen(inquiry: inq))),
              );
            },
          );
        },
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({required this.inquiry, required this.onTap});
  final Map<String, dynamic> inquiry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = inquiry['status'] as String? ?? 'pending';
    final unread = inquiry['unreadByAdmin'] as bool? ?? false;
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
    switch (status) {
      case 'replied':
        statusColor = const Color(0xFF16A34A); statusBg = const Color(0xFFDCFCE7); statusLabel = 'REPLIED';
      case 'closed':
        statusColor = const Color(0xFF64748B); statusBg = const Color(0xFFF1F5F9); statusLabel = 'CLOSED';
      default:
        statusColor = const Color(0xFFD97706); statusBg = const Color(0xFFFEF3C7); statusLabel = 'PENDING';
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
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(12)),
              child: const Icon(LucideIcons.building2, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(inquiry['contactName'] as String? ?? 'Unknown', style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 14, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (timeStr.isNotEmpty) Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(inquiry['shopName'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(child: Text(preview, style: TextStyle(fontSize: 12.5, color: unread ? const Color(0xFF0F172A) : const Color(0xFF64748B), fontWeight: unread ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                      ),
                      if (unread) ...[const SizedBox(width: 6), Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle))],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${inquiry['categoryOrProduct'] ?? ''} • ${inquiry['quantityRange'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminQuoteChatScreen extends StatefulWidget {
  const _AdminQuoteChatScreen({required this.inquiry});
  final Map<String, dynamic> inquiry;
  @override
  State<_AdminQuoteChatScreen> createState() => _AdminQuoteChatScreenState();
}

class _AdminQuoteChatScreenState extends State<_AdminQuoteChatScreen> {
  final _repo = FirestoreProductRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _status = widget.inquiry['status'] as String? ?? 'pending';
    _repo.markInquiryReadByAdmin(widget.inquiry['id'] as String);
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
      await _repo.sendInquiryMessage(inquiryId: widget.inquiry['id'] as String, senderId: 'admin', senderName: 'Goodwin Admin', text: text, isAdmin: true);
      setState(() => _status = 'replied');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendPhoto() async {
    if (_sending || _status == 'closed') return;
    final source = await showPhotoSourceActionSheet(context);
    if (source == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final photoUrl = await pickAndUploadChatPhoto(
        context,
        source,
        folder: 'inquiry_chats/${widget.inquiry['id']}',
      );
      if (photoUrl == null || !mounted) return;

      final caption = _textController.text.trim();
      _textController.clear();

      await _repo.sendInquiryMessage(
        inquiryId: widget.inquiry['id'] as String,
        senderId: 'admin',
        senderName: 'Goodwin Admin',
        text: caption,
        isAdmin: true,
        imageUrl: photoUrl,
      );
      setState(() => _status = 'replied');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = _status == 'closed' ? 'replied' : 'closed';
    await _repo.updateInquiryStatus(widget.inquiry['id'] as String, newStatus);
    if (mounted) setState(() => _status = newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final inq = widget.inquiry;
    final isClosed = _status == 'closed';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(inq['contactName'] as String? ?? 'Inquiry', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(inq['shopName'] as String? ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _toggleStatus,
            icon: Icon(isClosed ? LucideIcons.lockOpen : LucideIcons.lock, size: 15),
            label: Text(isClosed ? 'Reopen' : 'Close'),
            style: TextButton.styleFrom(foregroundColor: isClosed ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Column(
        children: [
          _InquirySummaryBanner(inquiry: inq),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _repo.streamInquiryMessages(inq['id'] as String),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                  return const Center(child: Text('No messages yet.\nSend the first reply below.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isAdminMsg = msg['senderId'] == 'admin';
                    return _ChatBubble(message: msg, isSentByMe: isAdminMsg);
                  },
                );
              },
            ),
          ),
          _ComposeBar(
            controller: _textController,
            sending: _sending,
            disabled: isClosed,
            onSend: _send,
            onAttachPhoto: _pickAndSendPhoto,
            placeholder: isClosed ? 'This inquiry is closed' : 'Type a reply to the customer…',
          ),
        ],
      ),
    );
  }
}

class _InquirySummaryBanner extends StatelessWidget {
  const _InquirySummaryBanner({required this.inquiry});
  final Map<String, dynamic> inquiry;
  @override
  Widget build(BuildContext context) {
    final photoUrl = inquiry['photoUrl'] as String? ?? '';
    return Container(
      width: double.infinity,
      color: const Color(0xFFEFF6FF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _SummaryChip(label: '📦 Product', value: inquiry['categoryOrProduct'] as String? ?? '—'),
              _SummaryChip(label: '🔢 Qty', value: inquiry['quantityRange'] as String? ?? '—'),
              _SummaryChip(label: '📞 Phone', value: inquiry['phone'] as String? ?? '—'),
              if ((inquiry['notes'] as String? ?? '').isNotEmpty) _SummaryChip(label: '📝 Notes', value: inquiry['notes'] as String),
            ],
          ),
          if (photoUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => FullScreenImageViewerDialog(
                  images: [photoUrl],
                  productName: inquiry['categoryOrProduct'] as String? ?? 'Sample Photo',
                ),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ProductImageWidget(
                      imageSrc: photoUrl,
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '📷 Attached Sample / Photo (Tap to view)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isSentByMe});
  final Map<String, dynamic> message;
  final bool isSentByMe;
  @override
  Widget build(BuildContext context) {
    final sentAt = message['sentAt'];
    String timeStr = '';
    if (sentAt is Timestamp) timeStr = DateFormat('hh:mm a').format(sentAt.toDate());
    final imageUrl = message['imageUrl'] as String? ?? '';
    final text = message['text'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe) ...[
            Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.user, color: Color(0xFF2563EB), size: 16)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSentByMe ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isSentByMe ? 16 : 4), bottomRight: Radius.circular(isSentByMe ? 4 : 16)),
                border: isSentByMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(message['senderName'] as String? ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSentByMe ? Colors.white70 : const Color(0xFF2563EB))),
                  if (imageUrl.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => FullScreenImageViewerDialog(
                            images: [imageUrl],
                            productName: 'Photo Attachment',
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 6, bottom: 4),
                        constraints: const BoxConstraints(maxHeight: 220, maxWidth: 260),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSentByMe ? Colors.white24 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: ProductImageWidget(
                            imageSrc: imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(text, style: TextStyle(fontSize: 14, color: isSentByMe ? Colors.white : const Color(0xFF0F172A), height: 1.4)),
                  ],
                  const SizedBox(height: 4),
                  Text(timeStr, style: TextStyle(fontSize: 10, color: isSentByMe ? Colors.white60 : const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
          if (isSentByMe) ...[
            const SizedBox(width: 8),
            Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 15)),
          ],
        ],
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  const _ComposeBar({
    required this.controller,
    required this.sending,
    required this.disabled,
    required this.onSend,
    required this.onAttachPhoto,
    required this.placeholder,
  });
  final TextEditingController controller;
  final bool sending;
  final bool disabled;
  final VoidCallback onSend;
  final VoidCallback onAttachPhoto;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 12, 10 + bottomInset),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.camera, color: Color(0xFF2563EB), size: 22),
            tooltip: 'Send Photo',
            onPressed: disabled ? null : (sending ? null : onAttachPhoto),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !disabled,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
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
