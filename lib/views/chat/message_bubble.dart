import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:coraldesk/models/models.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;

// ── Think-block parsing utilities ────────────────────────

/// A segment of text parsed from `<think>...</think>` blocks.
class _TextSegment {
  final String text;
  final bool isThinking;

  /// `false` when the `<think>` tag was opened but no matching `</think>`
  /// was found yet (still streaming).
  final bool isComplete;
  const _TextSegment(
    this.text, {
    this.isThinking = false,
    this.isComplete = true,
  });
}

/// Parse a raw text string into interleaved normal / thinking segments.
/// Handles `<think>...</think>` blocks, including unclosed ones (streaming).
List<_TextSegment> _parseThinkingBlocks(String text) {
  if (!text.contains('<think>') && !text.contains('<think')) {
    return [_TextSegment(text)];
  }

  final segments = <_TextSegment>[];
  final thinkOpen = RegExp(r'<think\s*>', caseSensitive: false);
  final thinkClose = RegExp(r'</think\s*>', caseSensitive: false);

  int pos = 0;
  while (pos < text.length) {
    final openMatch = thinkOpen.firstMatch(text.substring(pos));
    if (openMatch == null) {
      // No more think blocks
      final remaining = text.substring(pos).trim();
      if (remaining.isNotEmpty) {
        segments.add(_TextSegment(remaining));
      }
      break;
    }

    // Add text before <think>
    final beforeThink = text.substring(pos, pos + openMatch.start).trim();
    if (beforeThink.isNotEmpty) {
      segments.add(_TextSegment(beforeThink));
    }

    pos += openMatch.end;

    // Find closing </think>
    final closeMatch = thinkClose.firstMatch(text.substring(pos));
    if (closeMatch == null) {
      // Unclosed think block → still streaming
      final thinkContent = text.substring(pos).trim();
      segments.add(
        _TextSegment(thinkContent, isThinking: true, isComplete: false),
      );
      break;
    }

    // Complete think block
    final thinkContent = text.substring(pos, pos + closeMatch.start).trim();
    if (thinkContent.isNotEmpty) {
      segments.add(
        _TextSegment(thinkContent, isThinking: true, isComplete: true),
      );
    }
    pos += closeMatch.end;
  }

  return segments;
}

/// Individual message bubble with hover-based action bar (copy / edit / retry).
class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  /// Called when the user confirms an edit on their own message.
  /// Passes the new text back to the parent (ChatView) for re-send.
  final ValueChanged<String>? onEdit;

  /// Called when the user clicks the retry button.
  /// For user messages, re-sends the same message.
  /// For assistant messages, regenerates the response.
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.onEdit,
    this.onRetry,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _hovering = false;
  bool _editing = false;
  late TextEditingController _editController;

  ChatMessage get message => widget.message;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: message.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: message.content));
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.copiedToClipboard),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startEditing() {
    _editController.text = message.content;
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  void _confirmEditing() {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    setState(() => _editing = false);
    widget.onEdit?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    }
    return _buildAssistantBubble(context);
  }

  // ── User bubble ────────────────────────────────────────

  Widget _buildUserBubble(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Flexible(
                  flex: 8,
                  child: _editing
                      ? _buildEditField(c, l10n)
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              16,
                            ).copyWith(bottomRight: const Radius.circular(4)),
                          ),
                          child: Text(
                            message.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                _buildAvatar(
                  icon: Icons.person,
                  bgColor: AppColors.primaryLight,
                ),
              ],
            ),
            // Action bar: always reserve space, show on hover
            IgnorePointer(
              ignoring: !_hovering || _editing,
              child: AnimatedOpacity(
                opacity: _hovering && !_editing ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: const EdgeInsets.only(right: 44, top: 4),
                  child: SelectionContainer.disabled(
                    child: _buildActionBar(c, l10n, isUser: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(CoralDeskColors c, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _editController,
            maxLines: null,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: c.textPrimary, height: 1.5),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintStyle: TextStyle(color: c.textHint),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _cancelEditing,
                style: TextButton.styleFrom(
                  foregroundColor: c.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  l10n.cancelEdit,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _confirmEditing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.saveEdit,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Assistant bubble ───────────────────────────────────

  Widget _buildAssistantBubble(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasRole = message.agentRole != null && message.agentRole!.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role-specific avatar or default pet icon
                if (hasRole)
                  _buildRoleAvatar(
                    message.agentIcon ?? '🤖',
                    message.agentColor,
                  )
                else
                  _buildAvatar(icon: Icons.pets, bgColor: c.textPrimary),
                const SizedBox(width: 8),
                Flexible(
                  flex: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role name label above the bubble
                      if (hasRole)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message.agentRole!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: message.agentColor != null
                                  ? _RoleHeaderWidget._parseHexColor(
                                      message.agentColor!,
                                    )
                                  : c.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceBg,
                          borderRadius: BorderRadius.circular(
                            16,
                          ).copyWith(bottomLeft: const Radius.circular(4)),
                          border: Border.all(
                            color: hasRole && message.agentColor != null
                                ? _RoleHeaderWidget._parseHexColor(
                                    message.agentColor!,
                                  ).withValues(alpha: 0.25)
                                : c.chatListBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Prefer ordered parts when available
                            if (message.parts != null &&
                                message.parts!.isNotEmpty)
                              ..._buildPartsWidgets(c)
                            else ...[
                              // Fallback: legacy flat layout
                              if (message.toolCalls != null) ...[
                                for (final tc in message.toolCalls!)
                                  _ToolCallCard(toolCall: tc),
                                const SizedBox(height: 8),
                              ],
                              if (message.content.isNotEmpty)
                                ..._buildTextWithThinking(message.content, c),
                            ],

                            // Streaming indicator
                            if (message.isStreaming)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildStreamingDots(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
            // Action bar: always reserve space, show on hover (not during streaming)
            IgnorePointer(
              ignoring: !_hovering || message.isStreaming,
              child: AnimatedOpacity(
                opacity: _hovering && !message.isStreaming ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: const EdgeInsets.only(left: 44, top: 4),
                  child: SelectionContainer.disabled(
                    child: _buildActionBar(c, l10n, isUser: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Parts rendering ────────────────────────────────────

  /// Render an ordered list of TextPart / ToolCallPart / RoleHeaderPart widgets.
  List<Widget> _buildPartsWidgets(CoralDeskColors c) {
    final widgets = <Widget>[];
    for (final part in message.parts!) {
      switch (part) {
        case TextPart(:final text):
          if (text.isNotEmpty) {
            final segments = _parseThinkingBlocks(text);
            for (final seg in segments) {
              if (seg.isThinking) {
                if (widgets.isNotEmpty) {
                  widgets.add(const SizedBox(height: 6));
                }
                widgets.add(
                  _ThinkingBlock(
                    content: seg.text,
                    isComplete: seg.isComplete,
                    colors: c,
                    mdStyle: _mdStyle(c),
                  ),
                );
              } else {
                if (widgets.isNotEmpty) {
                  widgets.add(const SizedBox(height: 8));
                }
                widgets.add(
                  MarkdownBody(
                    data: seg.text,
                    styleSheet: _mdStyle(c),
                    selectable: false,
                  ),
                );
              }
            }
          }
        case ToolCallPart(:final toolCall):
          if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 4));
          widgets.add(_ToolCallCard(toolCall: toolCall));
        case RoleHeaderPart(:final roleName, :final roleColor, :final roleIcon):
          if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
          widgets.add(
            _RoleHeaderWidget(
              roleName: roleName,
              roleColor: roleColor,
              roleIcon: roleIcon,
            ),
          );
        case RoleHandoffPart(:final fromRole, :final toRole, :final summary):
          if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 4));
          widgets.add(
            _RoleHandoffWidget(
              fromRole: fromRole,
              toRole: toRole,
              summary: summary,
            ),
          );
      }
    }
    return widgets;
  }

  /// Parse text for `<think>` blocks and return widgets accordingly.
  /// Used by the fallback (non-parts) rendering path.
  List<Widget> _buildTextWithThinking(String text, CoralDeskColors c) {
    final segments = _parseThinkingBlocks(text);
    final widgets = <Widget>[];
    for (final seg in segments) {
      if (seg.isThinking) {
        widgets.add(
          _ThinkingBlock(
            content: seg.text,
            isComplete: seg.isComplete,
            colors: c,
            mdStyle: _mdStyle(c),
          ),
        );
      } else {
        widgets.add(
          MarkdownBody(
            data: seg.text,
            styleSheet: _mdStyle(c),
            selectable: false,
          ),
        );
      }
    }
    return widgets;
  }

  /// Shared markdown style sheet.
  MarkdownStyleSheet _mdStyle(CoralDeskColors c) {
    return MarkdownStyleSheet(
      p: TextStyle(fontSize: 14, height: 1.6, color: c.textPrimary),
      code: TextStyle(
        fontSize: 13,
        backgroundColor: c.inputBg,
        color: AppColors.primaryDark,
      ),
      codeblockDecoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(8),
      ),
      strong: const TextStyle(fontWeight: FontWeight.w600),
      listBullet: TextStyle(fontSize: 14, color: c.textPrimary),
    );
  }

  // ── Shared widgets ─────────────────────────────────────

  Widget _buildActionBar(
    CoralDeskColors c,
    AppLocalizations l10n, {
    required bool isUser,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.chatListBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionButton(
            icon: Icons.copy_outlined,
            tooltip: l10n.copyMessage,
            onTap: _copyContent,
            c: c,
          ),
          if (isUser && widget.onEdit != null)
            _actionButton(
              icon: Icons.edit_outlined,
              tooltip: l10n.editMessage,
              onTap: _startEditing,
              c: c,
            ),
          if (widget.onRetry != null)
            _actionButton(
              icon: Icons.refresh_outlined,
              tooltip: l10n.retryMessage,
              onTap: widget.onRetry!,
              c: c,
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required CoralDeskColors c,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: c.textSecondary),
        ),
      ),
    );
  }

  Widget _buildAvatar({required IconData icon, required Color bgColor}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  /// Build a circular avatar showing the role's emoji and tinted with its color.
  Widget _buildRoleAvatar(String emoji, String? colorHex) {
    final color = colorHex != null && colorHex.isNotEmpty
        ? _RoleHeaderWidget._parseHexColor(colorHex)
        : const Color(0xFF6C757D);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.50), width: 1.5),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
    );
  }

  Widget _buildStreamingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0),
        const SizedBox(width: 4),
        _dot(1),
        const SizedBox(width: 4),
        _dot(2),
      ],
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }
}

// ── Thinking Block Widget ────────────────────────────────

/// Collapsible card for `<think>...</think>` reasoning content.
///
/// * Default state: **collapsed** (only header visible).
/// * While the LLM is still streaming thinking content ([isComplete] == false),
///   a pulsing sparkle animation is shown.
/// * Tapping the header toggles expand / collapse with a smooth animation.
class _ThinkingBlock extends StatefulWidget {
  final String content;
  final bool isComplete;
  final CoralDeskColors colors;
  final MarkdownStyleSheet mdStyle;

  const _ThinkingBlock({
    required this.content,
    required this.isComplete,
    required this.colors,
    required this.mdStyle,
  });

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock>
    with TickerProviderStateMixin {
  bool _expanded = false;

  /// Pulsing glow animation for the "thinking in progress" indicator.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  /// Sparkle rotation animation.
  late final AnimationController _rotateController;
  late final Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _rotateAnimation = CurvedAnimation(
      parent: _rotateController,
      curve: Curves.linear,
    );

    if (!widget.isComplete) {
      _pulseController.repeat(reverse: true);
      _rotateController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ThinkingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isComplete && !oldWidget.isComplete) {
      // Thinking just finished — stop animations gracefully
      _pulseController.animateTo(0.0).then((_) {
        if (mounted) _pulseController.stop();
      });
      _rotateController.stop();
    } else if (!widget.isComplete && oldWidget.isComplete) {
      _pulseController.repeat(reverse: true);
      _rotateController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final l10n = AppLocalizations.of(context)!;
    final thinkLabel = widget.isComplete
        ? l10n.thinking.replaceAll('💭 ', '').replaceAll('...', '')
        : l10n.thinking.replaceAll('💭 ', '');

    // Accent colour for the thinking card
    final accent = const Color(0xFF9B8AE0); // soft purple

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (always visible, tappable) ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Animated sparkle icon
                  _buildSparkleIcon(accent),
                  const SizedBox(width: 8),
                  Text(
                    thinkLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      letterSpacing: 0.3,
                    ),
                  ),
                  // Streaming dots
                  if (!widget.isComplete) ...[
                    const SizedBox(width: 4),
                    _ThinkingDots(color: accent),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 18, color: accent),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable content ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: accent.withValues(alpha: 0.15)),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: widget.content,
                    styleSheet: widget.mdStyle.copyWith(
                      p: widget.mdStyle.p?.copyWith(
                        fontSize: 13,
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    selectable: true,
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  /// A sparkle ✦ icon that gently rotates and pulses while thinking.
  Widget _buildSparkleIcon(Color accent) {
    if (widget.isComplete) {
      return Icon(Icons.auto_awesome, size: 15, color: accent);
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotateAnimation]),
      builder: (context, child) {
        final pulse = 0.5 + 0.5 * _pulseAnimation.value;
        return Transform.rotate(
          angle: _rotateAnimation.value * 2 * math.pi,
          child: Opacity(
            opacity: pulse,
            child: Icon(Icons.auto_awesome, size: 15, color: accent),
          ),
        );
      },
    );
  }
}

/// Three small dots that fade in/out sequentially — used in the thinking
/// header while content is still streaming.
class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot fades at a slightly different phase
            final phase = (_ctrl.value + i * 0.25) % 1.0;
            final opacity = (math.sin(phase * math.pi)).clamp(0.2, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Opacity(
                opacity: opacity,
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: widget.color,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Expandable tool call card — refined design matching ThinkingBlock style.
///
/// Shows a compact header with tool name, status icon, and animated spinner
/// while running.  Expands to reveal arguments and result in styled code panels.
class _ToolCallCard extends StatefulWidget {
  final ToolCallInfo toolCall;

  const _ToolCallCard({required this.toolCall});

  @override
  State<_ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<_ToolCallCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  ToolCallInfo get toolCall => widget.toolCall;

  /// Spinning animation for the running state icon.
  late final AnimationController _spinController;

  /// Tool names that produce files
  static const _fileToolNames = {
    'file_write',
    'write_file',
    'filewrite',
    'writefile',
    'file_edit',
    'edit_file',
    'fileedit',
    'editfile',
  };

  /// Map common tool names to descriptive icons.
  static IconData _toolIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('file') || n.contains('read') || n.contains('write')) {
      return Icons.description_outlined;
    }
    if (n.contains('search') || n.contains('grep') || n.contains('find')) {
      return Icons.search_rounded;
    }
    if (n.contains('bash') ||
        n.contains('shell') ||
        n.contains('exec') ||
        n.contains('command') ||
        n.contains('terminal')) {
      return Icons.terminal_rounded;
    }
    if (n.contains('edit') || n.contains('patch') || n.contains('replace')) {
      return Icons.edit_note_rounded;
    }
    if (n.contains('list') || n.contains('dir') || n.contains('ls')) {
      return Icons.folder_open_rounded;
    }
    if (n.contains('web') || n.contains('http') || n.contains('fetch')) {
      return Icons.language_rounded;
    }
    if (n.contains('task') || n.contains('plan')) {
      return Icons.checklist_rounded;
    }
    return Icons.handyman_rounded;
  }

  /// Try to extract the file path from tool call arguments
  String? get _filePath {
    if (!_fileToolNames.contains(toolCall.name)) return null;
    if (toolCall.success != true) return null;
    try {
      final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
      return args['path'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Status-aware accent colour.
  Color get _accent => switch (toolCall.status) {
    ToolCallStatus.pending => const Color(0xFF9498A8),
    ToolCallStatus.running => AppColors.primary,
    ToolCallStatus.completed => AppColors.success,
    ToolCallStatus.failed => AppColors.error,
  };

  IconData get _statusIcon => switch (toolCall.status) {
    ToolCallStatus.pending => Icons.hourglass_empty_rounded,
    ToolCallStatus.running => Icons.sync_rounded,
    ToolCallStatus.completed => Icons.check_circle_rounded,
    ToolCallStatus.failed => Icons.cancel_rounded,
  };

  /// Try to pretty-print JSON, fall back to raw string
  String _formatJson(String raw) {
    try {
      final obj = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return raw;
    }
  }

  /// Build a short summary from tool arguments for the collapsed header.
  String _argsSummary() {
    if (toolCall.arguments.isEmpty) return '';
    try {
      final obj = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
      // Show first meaningful short value
      for (final key in [
        'path',
        'command',
        'query',
        'url',
        'pattern',
        'file_path',
        'regex',
      ]) {
        if (obj.containsKey(key)) {
          final val = obj[key].toString();
          if (val.length <= 60) return val;
          return '${val.substring(0, 57)}...';
        }
      }
    } catch (_) {}
    return '';
  }

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (toolCall.status == ToolCallStatus.running) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ToolCallCard old) {
    super.didUpdateWidget(old);
    if (toolCall.status == ToolCallStatus.running &&
        old.toolCall.status != ToolCallStatus.running) {
      _spinController.repeat();
    } else if (toolCall.status != ToolCallStatus.running &&
        old.toolCall.status == ToolCallStatus.running) {
      _spinController.stop();
      _spinController.reset();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final accent = _accent;
    final summary = _argsSummary();

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Status icon (animated spin while running)
                  _buildStatusIcon(accent),
                  const SizedBox(width: 8),
                  // Tool-type icon
                  Icon(
                    _toolIcon(toolCall.name),
                    size: 14,
                    color: accent.withValues(alpha: 0.70),
                  ),
                  const SizedBox(width: 6),
                  // Tool name
                  Flexible(
                    child: Text(
                      toolCall.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Brief argument summary
                  if (summary.isNotEmpty && !_expanded) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        summary,
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textHint,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  // Status badge
                  if (toolCall.result != null) _buildStatusBadge(c, accent),
                  // File action buttons
                  if (_filePath != null) ...[
                    const SizedBox(width: 4),
                    _FileActionButtons(filePath: _filePath!),
                  ],
                  const SizedBox(width: 4),
                  // Expand chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: accent.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable details ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildDetails(c, accent),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  /// Status icon — spins while running.
  Widget _buildStatusIcon(Color accent) {
    if (toolCall.status == ToolCallStatus.running) {
      return AnimatedBuilder(
        animation: _spinController,
        builder: (_, __) => Transform.rotate(
          angle: _spinController.value * 2 * math.pi,
          child: Icon(_statusIcon, size: 14, color: accent),
        ),
      );
    }
    return Icon(_statusIcon, size: 14, color: accent);
  }

  /// Small rounded "success/failed" badge.
  Widget _buildStatusBadge(CoralDeskColors c, Color accent) {
    final isOk = toolCall.success == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOk
            ? AppLocalizations.of(context)!.toolCallSuccess
            : AppLocalizations.of(context)!.toolCallFailed,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: accent,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Expanded details panel with arguments & result.
  Widget _buildDetails(CoralDeskColors c, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: accent.withValues(alpha: 0.12)),
          const SizedBox(height: 8),

          // Arguments
          if (toolCall.arguments.isNotEmpty) ...[
            _buildSectionHeader(c, accent, 'Arguments', isArgs: true),
            const SizedBox(height: 4),
            _buildCodeBlock(c, accent, _formatJson(toolCall.arguments)),
          ],

          // Result
          if (toolCall.result != null && toolCall.result!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSectionHeader(c, accent, 'Result', isArgs: false),
            const SizedBox(height: 4),
            _buildCodeBlock(c, accent, toolCall.result!),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    CoralDeskColors c,
    Color accent,
    String title, {
    required bool isArgs,
  }) {
    return Row(
      children: [
        Icon(
          isArgs ? Icons.input_rounded : Icons.output_rounded,
          size: 12,
          color: accent.withValues(alpha: 0.50),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        // Copy button
        SizedBox(
          height: 22,
          width: 22,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 13,
            icon: Icon(Icons.copy_rounded, color: c.textHint),
            tooltip: isArgs ? 'Copy arguments' : 'Copy result',
            onPressed: () {
              final text = isArgs
                  ? _formatJson(toolCall.arguments)
                  : toolCall.result ?? '';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.copiedToClipboard,
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCodeBlock(CoralDeskColors c, Color accent, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: c.mainBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          content,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
            color: c.textPrimary.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

/// Inline action buttons for file-producing tool calls (Open / Save as)
class _FileActionButtons extends StatelessWidget {
  final String filePath;

  const _FileActionButtons({required this.filePath});

  String get _fileName {
    final parts = filePath.split('/');
    return parts.isNotEmpty ? parts.last : filePath;
  }

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Open file
        SizedBox(
          height: 24,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11),
            ),
            icon: Icon(Icons.open_in_new, size: 13, color: AppColors.primary),
            label: Text(l10n.openFile),
            onPressed: () => agent_api.openInSystem(path: filePath),
          ),
        ),
        const SizedBox(width: 2),
        // Save as
        SizedBox(
          height: 24,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11),
            ),
            icon: Icon(Icons.save_alt, size: 13, color: c.textSecondary),
            label: Text(
              l10n.saveFileAs,
              style: TextStyle(color: c.textSecondary),
            ),
            onPressed: () async {
              final result = await FilePicker.platform.saveFile(
                dialogTitle: l10n.saveFileAs,
                fileName: _fileName,
              );
              if (result == null) return;
              final res = await agent_api.copyFileTo(
                src: filePath,
                dst: result,
              );
              if (!context.mounted) return;
              if (res.startsWith('error:')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.fileSaveFailed),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.fileSaved(res)),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

/// A visual header indicating which agent role is producing the following content.
class _RoleHeaderWidget extends StatelessWidget {
  final String roleName;
  final String roleColor;
  final String roleIcon;

  const _RoleHeaderWidget({
    required this.roleName,
    required this.roleColor,
    required this.roleIcon,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseHexColor(roleColor);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(roleIcon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            roleName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  static Color _parseHexColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return const Color(0xFF6C757D); // fallback grey
  }
}

/// A visual marker showing a task handoff between two agent roles.
class _RoleHandoffWidget extends StatelessWidget {
  final String fromRole;
  final String toRole;
  final String summary;

  const _RoleHandoffWidget({
    required this.fromRole,
    required this.toRole,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F8);
    final borderColor = isDark
        ? const Color(0xFF4A4A6A)
        : const Color(0xFFD0D0E0);
    final textColor = isDark
        ? const Color(0xFFB0B0CC)
        : const Color(0xFF6060A0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: fromRole,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  TextSpan(
                    text: ' → ',
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                  TextSpan(
                    text: toRole.isEmpty ? 'orchestrator' : toRole,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    TextSpan(
                      text: '  · $summary',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
