import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import 'theme.dart';

typedef HugeIconData = List<List<dynamic>>;

/// Wraps [text] in a left-to-right isolate so phone numbers, codes and
/// plates keep their order inside Arabic sentences.
String ltr(String text) => '\u2066$text\u2069';

/// Hugeicons stroke icon, the icon set the NDS canvas uses. Follows the
/// ambient [IconTheme] color unless [color] is given.
class AppIcon extends StatelessWidget {
  final HugeIconData icon;
  final double size;
  final Color? color;

  const AppIcon(this.icon, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) =>
      HugeIcon(icon: icon, size: size, color: color, strokeWidth: 1.5);
}

class KkuLogo extends StatelessWidget {
  final double? width;
  final double? height;

  const KkuLogo({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/kku_logo.svg',
    width: width,
    height: height,
    semanticsLabel: 'شعار جامعة الملك خالد',
  );
}

/// White header with the university logo, a portal title and optional
/// trailing actions (the canvas "brandbar").
class BrandBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showLogo;

  const BrandBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showLogo = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return _BarFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          if (showLogo) ...[
            const KkuLogo(height: 52),
            const SizedBox(width: Space.lg),
            Container(width: 1, height: 36, color: Nds.borderNeutral),
            const SizedBox(width: Space.lg),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NdsText.textMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Nds.textDisplay,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NdsText.textXs.copyWith(color: Nds.textSecondary),
                  ),
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: Space.md),
            action,
          ],
        ],
      ),
    );
  }
}

/// Centered page title with a round back button (the canvas "appbar").
/// The back button appears whenever the route can pop.
class NdsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;

  const NdsAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && (ModalRoute.of(context)?.canPop ?? false);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return _BarFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.lg,
      ),
      child: Row(
        children: [
          if (canPop)
            CircleIconButton(
              icon: rtl
                  ? HugeIcons.strokeRoundedArrowRight01
                  : HugeIcons.strokeRoundedArrowLeft01,
              tooltip: 'رجوع',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 40),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: NdsText.textLg.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Nds.textDisplay,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: NdsText.textXs.copyWith(color: Nds.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.lg),
          trailing ?? const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _BarFrame extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _BarFrame({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Nds.backgroundDefault,
        border: Border(bottom: BorderSide(color: Nds.borderNeutral)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 72,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class NdsTabItem {
  final HugeIconData icon;
  final String label;

  const NdsTabItem(this.icon, this.label);
}

/// Bottom navigation: icon over label, the current tab in primary green.
class NdsTabBar extends StatelessWidget {
  final List<NdsTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const NdsTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Nds.backgroundDefault,
        border: Border(top: BorderSide(color: Nds.borderNeutral)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: Space.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _tab(items[i], i == currentIndex, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(NdsTabItem item, bool selected, int index) {
    final color = selected ? Nds.textPrimary : Nds.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(Radii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(item.icon, color: color),
              const SizedBox(height: Space.xxs),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NdsText.textXs.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White bottom bar holding the page's main action (the canvas "footer").
class NdsFooter extends StatelessWidget {
  final List<Widget> children;

  const NdsFooter({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Nds.backgroundDefault,
        border: Border(top: BorderSide(color: Nds.borderNeutral)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: Space.xl),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, 0),
          child: NdsGroup(gap: Space.lg, children: children),
        ),
      ),
    );
  }
}

/// Scrollable page content with the canvas body padding and gaps, and
/// pull-to-refresh when [onRefresh] is given.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double gap;

  const PageBody({
    super.key,
    required this.children,
    this.onRefresh,
    this.gap = Space.xl,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.x2l,
      ),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Stretched column with even gaps (the canvas "group").
class NdsGroup extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  const NdsGroup({
    super.key,
    required this.children,
    this.gap = Space.md,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}

/// Page heading with an optional lead paragraph.
class PageHeading extends StatelessWidget {
  final String title;
  final String? lead;

  const PageHeading(this.title, {super.key, this.lead});

  @override
  Widget build(BuildContext context) {
    return NdsGroup(
      gap: Space.xxs,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: NdsText.displayXs.copyWith(color: Nds.textDisplay),
          ),
        ),
        if (lead != null)
          Text(lead!, style: NdsText.textSm.copyWith(color: Nds.textSecondary)),
      ],
    );
  }
}

/// 40px round outlined icon button (NDS secondary-outline, icon-only).
class CircleIconButton extends StatelessWidget {
  final HugeIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int badgeCount;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final glyph = AppIcon(icon, size: 20);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        foregroundColor: Nds.textDisplay,
        side: const BorderSide(color: NdsColors.neutral300),
        shape: const CircleBorder(),
      ),
      icon: badgeCount > 0
          ? Badge.count(
              count: badgeCount,
              backgroundColor: NdsColors.red600,
              child: glyph,
            )
          : glyph,
    );
  }
}

/// Button styles the theme does not cover.
abstract final class NdsButtons {
  /// 40px button for actions inside cards and lists.
  static final compact = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: Space.lg),
    ),
    textStyle: WidgetStatePropertyAll(
      NdsText.textSm.copyWith(fontWeight: FontWeight.w500),
    ),
  );

  /// 32px button, as in alert actions.
  static final small = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: Space.lg),
    ),
    textStyle: WidgetStatePropertyAll(
      NdsText.textSm.copyWith(fontWeight: FontWeight.w500),
    ),
  );

  static final destructiveOutline = ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? NdsColors.neutral400
          : Nds.textError,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? Nds.borderNeutral
            : NdsColors.red600,
      ),
    ),
  );

  static final destructive = ElevatedButton.styleFrom(
    backgroundColor: NdsColors.red600,
    foregroundColor: NdsColors.white,
  );

  /// Outline button on the deep green hero panel.
  static final onColorOutline = OutlinedButton.styleFrom(
    foregroundColor: Nds.textOnColor,
    backgroundColor: Colors.transparent,
    side: const BorderSide(color: Color(0x99FFFFFF)),
    minimumSize: const Size.fromHeight(40),
  );
}

/// Two-way choice inside a card: filled when selected, outlined otherwise.
class ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  const ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: selected
          ? ElevatedButton.icon(
              onPressed: onPressed,
              style: NdsButtons.compact,
              icon: const AppIcon(HugeIcons.strokeRoundedTick02, size: 18),
              label: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: NdsButtons.compact,
              child: Text(label),
            ),
    );
  }
}

/// White bordered card (the canvas "panel").
class NdsPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  const NdsPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.color = Nds.backgroundCard,
    this.borderColor = Nds.borderNeutral,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: child,
    );
  }
}

/// Deep green summary card at the top of each home screen ("panel-deep").
class HeroPanel extends StatelessWidget {
  final List<Widget> children;

  const HeroPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: Nds.backgroundPrimaryStrong,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: IconTheme.merge(
        data: const IconThemeData(color: Nds.textOnColor),
        child: DefaultTextStyle.merge(
          style: NdsText.textSm.copyWith(color: Nds.textOnColor),
          child: NdsGroup(gap: Space.lg, children: children),
        ),
      ),
    );
  }
}

class HeroDivider extends StatelessWidget {
  const HeroDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: Nds.borderOnColor);
}

/// Hero heading: small caption, large title and an optional tag.
class HeroHeading extends StatelessWidget {
  final String caption;
  final String title;
  final String? tag;

  const HeroHeading({
    super.key,
    required this.caption,
    required this.title,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: NdsText.textXs.copyWith(color: Nds.textOnColorSecondary),
              ),
              Text(
                title,
                style: NdsText.displayXs.copyWith(color: Nds.textOnColor),
              ),
            ],
          ),
        ),
        if (tag != null) ...[
          const SizedBox(width: Space.md),
          NdsTag(tag!, status: TagStatus.onColor),
        ],
      ],
    );
  }
}

/// Icon, caption and value line inside the hero panel.
class HeroInfoRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;

  const HeroInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppIcon(icon, size: 20, color: Nds.textOnColor),
        ),
        const SizedBox(width: Space.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: NdsText.textXs.copyWith(color: Nds.textOnColorSecondary),
              ),
              Text(
                value,
                style: NdsText.textSm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Nds.textOnColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Caption on one side, figure on the other ("between meta").
class ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool onColor;

  const ValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.onColor = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: NdsText.textSm.copyWith(
              color: onColor ? Nds.textOnColorSecondary : Nds.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: Space.md),
        Text(
          value,
          style: NdsText.textSm.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? (onColor ? Nds.textOnColor : Nds.textDisplay),
          ),
        ),
      ],
    );
  }
}

enum TagStatus { neutral, success, info, warning, error, onColor }

/// Status pill with a leading dot (NDS tag with data-status).
class NdsTag extends StatelessWidget {
  final String label;
  final TagStatus status;
  final bool small;

  const NdsTag(
    this.label, {
    super.key,
    this.status = TagStatus.neutral,
    this.small = true,
  });

  @override
  Widget build(BuildContext context) {
    final (background, border, text) = switch (status) {
      TagStatus.neutral => (
        NdsColors.neutral50,
        Nds.borderNeutral,
        NdsColors.neutral800,
      ),
      TagStatus.success => (
        NdsColors.green50,
        NdsColors.green200,
        NdsColors.green800,
      ),
      TagStatus.info => (
        NdsColors.blue50,
        NdsColors.blue200,
        NdsColors.blue800,
      ),
      TagStatus.warning => (
        NdsColors.yellow50,
        NdsColors.yellow200,
        NdsColors.yellow800,
      ),
      TagStatus.error => (NdsColors.red50, NdsColors.red200, NdsColors.red800),
      TagStatus.onColor => (
        const Color(0x33FFFFFF),
        const Color(0x99FFFFFF),
        Nds.textOnColor,
      ),
    };
    return Container(
      height: small ? 24 : 32,
      padding: EdgeInsets.symmetric(horizontal: small ? Space.md : Space.lg),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != TagStatus.onColor) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: text, shape: BoxShape.circle),
            ),
            const SizedBox(width: Space.xs),
          ],
          Text(
            label,
            style: (small ? NdsText.textXs : NdsText.textSm).copyWith(
              fontWeight: FontWeight.w500,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}

enum Tone { primary, neutral, success, info, warning, error }

(Color background, Color foreground) toneColors(Tone tone) => switch (tone) {
  Tone.primary => (Nds.backgroundPrimaryLight, Nds.textPrimary),
  Tone.neutral => (Nds.backgroundNeutralLight, Nds.iconNeutral),
  Tone.success => (NdsColors.green50, NdsColors.green600),
  Tone.info => (NdsColors.blue50, NdsColors.blue600),
  Tone.warning => (NdsColors.yellow50, NdsColors.yellow600),
  Tone.error => (NdsColors.red50, NdsColors.red600),
};

/// Icon on a tinted rounded square or circle (NDS featured icon).
class FeaturedIcon extends StatelessWidget {
  final HugeIconData icon;
  final double size;
  final Tone tone;
  final bool circle;

  const FeaturedIcon(
    this.icon, {
    super.key,
    this.size = 40,
    this.tone = Tone.primary,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = toneColors(tone);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: circle ? null : BorderRadius.circular(size / 4 - 2),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: AppIcon(icon, size: size / 2, color: foreground),
    );
  }
}

/// Round avatar showing up to two initials.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const InitialsAvatar(this.name, {super.key, this.size = 40});

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$last';
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Nds.backgroundNeutralLight,
          shape: BoxShape.circle,
        ),
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontFamily: Nds.fontFamily,
            fontSize: size / 3,
            fontWeight: FontWeight.w500,
            color: Nds.textDefault,
          ),
        ),
      ),
    );
  }
}

/// Avatar with the greeting and date at the top of each home screen.
class GreetingHeader extends StatelessWidget {
  final String name;
  final String greeting;
  final String? subtitle;

  const GreetingHeader({
    super.key,
    required this.name,
    required this.greeting,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialsAvatar(name, size: 48),
        const SizedBox(width: Space.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: NdsText.textXl.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Nds.textDisplay,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: NdsText.textSm.copyWith(color: Nds.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Large centered avatar, name and role line on account screens.
class ProfileHeader extends StatelessWidget {
  final String name;
  final String? meta;

  const ProfileHeader({super.key, required this.name, this.meta});

  @override
  Widget build(BuildContext context) {
    return NdsGroup(
      gap: Space.sm,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InitialsAvatar(name, size: 80),
        const SizedBox(height: Space.xxs),
        Text(
          name,
          textAlign: TextAlign.center,
          style: NdsText.displayXs.copyWith(color: Nds.textDisplay),
        ),
        if (meta != null)
          Text(
            meta!,
            textAlign: TextAlign.center,
            style: NdsText.textSm.copyWith(color: Nds.textSecondary),
          ),
      ],
    );
  }
}

/// Text field with its label above it, as NDS forms lay them out.
class NdsField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final HugeIconData? icon;
  final String? hint;
  final String? helper;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  const NdsField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.hint,
    this.helper,
    this.obscureText = false,
    this.keyboardType,
    this.textDirection,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: NdsText.textSm.copyWith(
              fontWeight: FontWeight.w500,
              color: Nds.textDefault,
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textDirection: textDirection,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            validator: validator,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmitted,
            style: NdsText.textMd.copyWith(color: Nds.textDefault),
            decoration: InputDecoration(
              hintText: hint,
              hintTextDirection: textDirection,
              helperText: helper,
              helperMaxLines: 2,
              helperStyle: NdsText.textXs.copyWith(color: Nds.textSecondary),
              prefixIcon: icon == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      child: AppIcon(icon!, size: 20),
                    ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single-select filter chips.
class NdsChoiceChips<T> extends StatelessWidget {
  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const NdsChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.md,
      children: [
        for (final (value, label) in options)
          _chip(label, value == selected, () => onSelected(value)),
      ],
    );
  }

  Widget _chip(String label, bool pressed, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: pressed,
      child: Material(
        color: pressed ? Nds.backgroundPrimary : Nds.backgroundNeutralLight,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: NdsText.textSm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: pressed ? Nds.textOnColor : NdsColors.neutral800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered list row: leading visual, title and meta lines, optional
/// trailing widget, and optional content below (the canvas "item").
class NdsListItem extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? titleBadge;
  final String? meta;
  final String? meta2;
  final Widget? trailing;
  final Widget? bottom;
  final VoidCallback? onTap;
  final bool chevron;

  const NdsListItem({
    super.key,
    this.leading,
    required this.title,
    this.titleBadge,
    this.meta,
    this.meta2,
    this.trailing,
    this.bottom,
    this.onTap,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final metaStyle = NdsText.textSm.copyWith(color: Nds.textSecondary);
    final row = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: Space.lg)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: NdsText.textMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Nds.textDisplay,
                    ),
                  ),
                  ?titleBadge,
                ],
              ),
              if (meta?.isNotEmpty ?? false) Text(meta!, style: metaStyle),
              if (meta2?.isNotEmpty ?? false) Text(meta2!, style: metaStyle),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Space.lg), trailing!],
        if (chevron) ...[
          const SizedBox(width: Space.md),
          AppIcon(
            rtl
                ? HugeIcons.strokeRoundedArrowLeft01
                : HugeIcons.strokeRoundedArrowRight01,
            size: 20,
            color: Nds.iconNeutral,
          ),
        ],
      ],
    );
    return Material(
      color: Nds.backgroundCard,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Nds.borderNeutral),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xl,
            vertical: Space.lg,
          ),
          child: bottom == null
              ? row
              : NdsGroup(gap: Space.lg, children: [row, bottom!]),
        ),
      ),
    );
  }
}

/// Square shortcut card with an icon and label (the canvas "tile").
class NdsTile extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final Tone tone;
  final VoidCallback? onTap;

  const NdsTile({
    super.key,
    required this.icon,
    required this.label,
    this.tone = Tone.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Nds.backgroundCard,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Nds.borderNeutral),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FeaturedIcon(icon, tone: tone),
              const SizedBox(height: Space.lg),
              Text(
                label,
                style: NdsText.textMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Nds.textDisplay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays [children] out in rows of [columns] equal-width, equal-height cells.
class NdsGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double gap;

  const NdsGrid({
    super.key,
    required this.children,
    required this.columns,
    this.gap = Space.md,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final cells = <Widget>[];
      for (var i = start; i < start + columns; i++) {
        if (i > start) cells.add(SizedBox(width: gap));
        cells.add(
          Expanded(child: i < children.length ? children[i] : const SizedBox()),
        );
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return NdsGroup(gap: gap, children: rows);
  }
}

/// Bordered figure with a caption (the canvas "stat").
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final bool centered;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: Nds.backgroundCard,
        border: Border.all(color: Nds.borderNeutral),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: NdsText.displayXs.copyWith(color: color ?? Nds.textDisplay),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            label,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: NdsText.textXs.copyWith(color: Nds.textSecondary),
          ),
        ],
      ),
    );
  }
}

class KvEntry {
  final String label;
  final String value;
  final Color? color;

  const KvEntry(this.label, this.value, {this.color});
}

/// Label/value rows separated by dividers (the canvas "kv" list).
class KvList extends StatelessWidget {
  final List<KvEntry> entries;

  const KvList(this.entries, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          Container(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : Space.md,
              bottom: i == entries.length - 1 ? 0 : Space.md,
            ),
            decoration: i == entries.length - 1
                ? null
                : const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Nds.divider)),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entries[i].label,
                  style: NdsText.textSm.copyWith(color: Nds.textSecondary),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Text(
                    entries[i].value,
                    textAlign: TextAlign.end,
                    style: NdsText.textSm.copyWith(
                      fontWeight: FontWeight.w500,
                      color: entries[i].color ?? Nds.textDefault,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Panel with a section heading, optional trailing widget and content.
class TitledPanel extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const TitledPanel({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NdsPanel(
      child: NdsGroup(
        gap: Space.lg,
        children: [
          SectionTitle(title, trailing: trailing),
          child,
        ],
      ),
    );
  }
}

/// Heading followed by its content (the canvas "group" with h-section).
class Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const Section({
    super.key,
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return NdsGroup(
      children: [
        SectionTitle(title, trailing: trailing),
        ...children,
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: NdsText.textMd.copyWith(
                fontWeight: FontWeight.w600,
                color: Nds.textDisplay,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Card alert with a status stripe, icon, text and optional action.
class NdsAlert extends StatelessWidget {
  final TagStatus status;
  final String title;
  final String? description;
  final Widget? action;

  const NdsAlert({
    super.key,
    required this.status,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      TagStatus.success => (
        NdsColors.green600,
        HugeIcons.strokeRoundedCheckmarkCircle02,
      ),
      TagStatus.info => (
        NdsColors.blue600,
        HugeIcons.strokeRoundedInformationCircle,
      ),
      TagStatus.warning => (
        NdsColors.yellow600,
        HugeIcons.strokeRoundedAlert02,
      ),
      TagStatus.error => (NdsColors.red600, HugeIcons.strokeRoundedAlertCircle),
      _ => (NdsColors.neutral500, HugeIcons.strokeRoundedInformationCircle),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Nds.backgroundDefault,
          border: Border.all(color: Nds.borderNeutral),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: color),
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(icon, size: 24, color: color),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: NdsText.textMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Nds.textDisplay,
                          ),
                        ),
                        if (description != null)
                          Text(
                            description!,
                            style: NdsText.textSm.copyWith(
                              color: Nds.textParagraph,
                            ),
                          ),
                        if (action != null) ...[
                          const SizedBox(height: Space.md),
                          action!,
                        ],
                      ],
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

/// Icon and short sentence, for notes inside a page (NDS inline alert).
class InlineNote extends StatelessWidget {
  final String text;
  final HugeIconData icon;
  final Color color;

  const InlineNote(
    this.text, {
    super.key,
    this.icon = HugeIcons.strokeRoundedInformationCircle,
    this.color = NdsColors.blue600,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: 20, color: color),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            text,
            style: NdsText.textSm.copyWith(color: Nds.textParagraph),
          ),
        ),
      ],
    );
  }
}

/// Thin rounded progress track (0..1).
class ProgressTrack extends StatelessWidget {
  final double value;
  final String semanticsLabel;
  final bool onColor;

  const ProgressTrack({
    super.key,
    required this.value,
    required this.semanticsLabel,
    this.onColor = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.full),
      child: LinearProgressIndicator(
        value: value.isNaN ? 0 : value.clamp(0, 1),
        minHeight: 8,
        color: onColor ? Nds.textOnColor : Nds.backgroundPrimary,
        backgroundColor: onColor
            ? const Color(0x33FFFFFF)
            : Nds.backgroundNeutralLight,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}

/// Row of small centered figures with captions (the canvas "minis").
class MiniStats extends StatelessWidget {
  final List<(String value, String label, Color? color)> items;

  const MiniStats({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (value, label, color) in items)
          Expanded(
            child: Column(
              children: [
                Text(
                  value,
                  style: NdsText.textLg.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color ?? Nds.textDisplay,
                  ),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: NdsText.textXs.copyWith(color: Nds.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Grey grid standing in for a map that has nothing to show yet.
class MapPlaceholder extends StatelessWidget {
  final String text;
  final HugeIconData icon;

  const MapPlaceholder({
    super.key,
    required this.text,
    this.icon = HugeIcons.strokeRoundedLocation01,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 32, color: Nds.iconNeutral),
            const SizedBox(height: Space.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: NdsText.textSm.copyWith(color: Nds.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Nds.backgroundNeutralLight,
    );
    final line = Paint()
      ..color = Nds.divider
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Centered icon, title and message for empty and error states.
class MessageView extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final String? message;
  final Tone tone;
  final Widget? action;

  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.tone = Tone.neutral,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x2l,
        vertical: Space.x4l,
      ),
      child: NdsGroup(
        gap: Space.md,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FeaturedIcon(icon, size: 56, tone: tone, circle: true),
          const SizedBox(height: Space.xs),
          Text(
            title,
            textAlign: TextAlign.center,
            style: NdsText.textLg.copyWith(
              fontWeight: FontWeight.w600,
              color: Nds.textDisplay,
            ),
          ),
          if (message != null)
            Text(
              message!,
              textAlign: TextAlign.center,
              style: NdsText.textSm.copyWith(color: Nds.textSecondary),
            ),
          if (action != null) ...[const SizedBox(height: Space.sm), action!],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const ErrorView({
    super.key,
    this.title = 'تعذر تحميل البيانات',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: MessageView(
          icon: HugeIcons.strokeRoundedAlertCircle,
          tone: Tone.error,
          title: title,
          message: 'تحقق من الاتصال ثم حاول مرة أخرى.',
          action: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const AppIcon(HugeIcons.strokeRoundedRefresh, size: 20),
            label: const Text('إعادة المحاولة'),
          ),
        ),
      ),
    );
  }
}

/// Bottom confirmation sheet; resolves to true when confirmed.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'إلغاء',
  bool destructive = false,
  HugeIconData icon = HugeIcons.strokeRoundedAlertCircle,
  Tone tone = Tone.warning,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Nds.backgroundDefault,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.xl,
          Space.x2l,
          Space.xl,
          Space.x3l,
        ),
        child: NdsGroup(
          gap: Space.x2l,
          children: [
            NdsGroup(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FeaturedIcon(icon, size: 48, tone: tone, circle: true),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: NdsText.textXl.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Nds.textDisplay,
                  ),
                ),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: NdsText.textMd.copyWith(color: Nds.textSecondary),
                ),
              ],
            ),
            NdsGroup(
              children: [
                ElevatedButton(
                  style: destructive ? NdsButtons.destructive : null,
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: Text(confirmLabel),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(cancelLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? NdsColors.red700 : null,
    ),
  );
}
