import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _scrollController = ScrollController();
  final _signInSectionKey = GlobalKey();
  final _briefingSectionKey = GlobalKey();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    try {
      await AuthRepository(
        ref.read(supabaseProvider),
      ).signIn(email: _email.text.trim(), password: _password.text);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'PropertyOS could not contact the sign-in service.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    try {
      await AuthRepository(
        ref.read(supabaseProvider),
      ).requestPasswordReset(email: email);
      if (mounted) {
        setState(
          () => _notice =
              'Password reset email sent. Use the newest link in your inbox.',
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'PropertyOS could not send the reset email.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        body: SelectionArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                _HeroSection(
                  signInKey: _signInSectionKey,
                  form: _SignInCard(
                    key: _signInSectionKey,
                    formKey: _formKey,
                    email: _email,
                    password: _password,
                    obscure: _obscure,
                    submitting: _submitting,
                    error: _error,
                    notice: _notice,
                    onTogglePassword: () =>
                        setState(() => _obscure = !_obscure),
                    onSignIn: _signIn,
                    onResetPassword: _requestPasswordReset,
                  ),
                  onEnterAlpha: () => _scrollTo(_signInSectionKey),
                  onViewBriefing: () => _scrollTo(_briefingSectionKey),
                ),
                const _ProblemSection(),
                const _DifferenceSection(),
                const _CapabilitiesSection(),
                _DailyBriefingShowcase(key: _briefingSectionKey),
                const _AudienceSection(),
                const _DisclaimerSection(),
                _FinalCta(onEnterAlpha: () => _scrollTo(_signInSectionKey)),
              ],
            ),
          ),
        ),
      );
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.signInKey,
    required this.form,
    required this.onEnterAlpha,
    required this.onViewBriefing,
  });

  final GlobalKey signInKey;
  final Widget form;
  final VoidCallback onEnterAlpha;
  final VoidCallback onViewBriefing;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06131F), Color(0xFF0A2438), Color(0xFF102F46)],
          ),
        ),
        child: Column(
          children: [
            _TopNav(
              onEnterAlpha: onEnterAlpha,
              onViewBriefing: onViewBriefing,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 96),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 900;
                    return Flex(
                      direction: narrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: narrow ? 0 : 9,
                          child: _HeroCopy(
                            onEnterAlpha: onEnterAlpha,
                            onViewBriefing: onViewBriefing,
                          ),
                        ),
                        SizedBox(
                            width: narrow ? 0 : 52, height: narrow ? 36 : 0),
                        Expanded(
                          flex: narrow ? 0 : 10,
                          child: _HeroPreview(form: form),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
}

class _TopNav extends StatelessWidget {
  const _TopNav({required this.onEnterAlpha, required this.onViewBriefing});

  final VoidCallback onEnterAlpha;
  final VoidCallback onViewBriefing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              const _BrandMark(),
              const SizedBox(width: 12),
              const Text(
                'PropertyOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const Spacer(),
              _NavButton(label: 'Daily Briefing', onPressed: onViewBriefing),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF071827),
                ),
                onPressed: onEnterAlpha,
                child: const Text('Enter Alpha'),
              ),
            ],
          ),
        ),
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFDDE7F0)),
        ),
      );
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onEnterAlpha, required this.onViewBriefing});

  final VoidCallback onEnterAlpha;
  final VoidCallback onViewBriefing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.12),
              border:
                  Border.all(color: const Color(0xFFA7F3D0).withOpacity(0.25)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'AI-first landlord operations',
              style: TextStyle(
                color: Color(0xFFA7F3D0),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'The AI operating system for independent UK landlords.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 64,
              height: 0.95,
              fontWeight: FontWeight.w800,
              letterSpacing: -4.2,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Manage compliance, documents, maintenance, tenancy events and portfolio decisions from one intelligent daily briefing.',
            style: TextStyle(
              color: Color(0xFFC8D3DD),
              fontSize: 20,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF071827),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                onPressed: onEnterAlpha,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Enter Alpha'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.22)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                onPressed: onViewBriefing,
                child: const Text('View Daily Briefing'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Built for independent UK residential landlords managing 5–50 properties.',
            style: TextStyle(color: Color(0xFF9DAFBE)),
          ),
        ],
      );
}

class _HeroPreview extends StatelessWidget {
  const _HeroPreview({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 46,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Column(
          children: [
            _TodayPreviewCard(),
            const SizedBox(height: 16),
            form,
          ],
        ),
      );
}

class _TodayPreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: const Color(0xFFF7F9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StatusPill(
                  label: 'Portfolio healthy', tone: _PillTone.good),
              const SizedBox(height: 14),
              const Text(
                'Good morning Karl.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your portfolio is mostly healthy today. No urgent compliance issues were found. One gas safety certificate expires in 31 days. One tenancy ends in 47 days. Two maintenance issues are awaiting action.',
                style: TextStyle(color: Color(0xFF667085), height: 1.55),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 480;
                  final metrics = const [
                    _Metric(label: 'Properties', value: '8'),
                    _Metric(label: 'Monthly rent', value: '£8,950'),
                    _Metric(label: 'Open tasks', value: '5'),
                  ];
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: metrics
                        .map(
                          (metric) => SizedBox(
                            width: narrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 20) / 3,
                            child: metric,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    super.key,
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.submitting,
    required this.error,
    required this.notice,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onResetPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool submitting;
  final String? error;
  final String? notice;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Private Alpha sign-in',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Access is invitation-only while we validate the first landlord workflows.',
                  style: TextStyle(color: Color(0xFF667085)),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter a valid email address'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  onFieldSubmitted: (_) => onSignIn(),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password'
                      : null,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      notice!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: submitting ? null : onSignIn,
                  child: Text(submitting ? 'Please wait…' : 'Sign in'),
                ),
                TextButton(
                  onPressed: submitting ? null : onResetPassword,
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ProblemSection extends StatelessWidget {
  const _ProblemSection();

  @override
  Widget build(BuildContext context) => const _PageSection(
        background: Colors.white,
        title: 'Landlord admin is scattered everywhere.',
        body:
            'Most landlords do not need more software screens. They need clarity. PropertyOS brings portfolio information together and turns it into daily intelligence.',
        child: _ProblemGrid(),
      );
}

class _ProblemGrid extends StatelessWidget {
  const _ProblemGrid();

  @override
  Widget build(BuildContext context) => const _ResponsiveGrid(
        minItemWidth: 240,
        children: [
          _InfoCard(
              icon: 'X',
              title: 'Spreadsheets',
              body: 'Static trackers that quietly go stale.'),
          _InfoCard(
              icon: '@',
              title: 'Email threads',
              body:
                  'Repairs, renewals and tenant messages buried in the inbox swamp.'),
          _InfoCard(
              icon: 'PDF',
              title: 'Certificates',
              body: 'Gas Safety, EPC and EICR dates hiding inside documents.'),
          _InfoCard(
              icon: '!',
              title: 'Deadlines',
              body:
                  'Compliance reminders scattered across calendars, folders and memory.'),
        ],
      );
}

class _DifferenceSection extends StatelessWidget {
  const _DifferenceSection();

  @override
  Widget build(BuildContext context) => _PageSection(
        title: 'Not property management software. Property intelligence.',
        body:
            'Traditional systems store data. PropertyOS uses documents, events and timelines to tell landlords what needs attention next.',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            final children = [
              const _CompareCard(
                title: 'Traditional landlord software',
                items: [
                  'Stores records',
                  'Requires manual updates',
                  'Shows static dashboards',
                  'Relies on users to remember deadlines',
                  'Feels like a database',
                ],
              ),
              const _CompareCard(
                title: 'PropertyOS',
                highlighted: true,
                items: [
                  'Reads documents',
                  'Creates reminders automatically',
                  'Builds property timelines',
                  'Generates daily briefings',
                  'Recommends next actions',
                  'Answers questions in plain English',
                ],
              ),
            ];
            return Flex(
              direction: narrow ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children
                  .map(
                    (child) => Expanded(
                      flex: narrow ? 0 : 1,
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: narrow ? 0 : 18,
                          bottom: narrow ? 18 : 0,
                        ),
                        child: child,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      );
}

class _CapabilitiesSection extends StatelessWidget {
  const _CapabilitiesSection();

  @override
  Widget build(BuildContext context) => const _PageSection(
        background: Colors.white,
        title: 'Everything starts with what matters today.',
        body:
            'The prototype demonstrates the core concepts that make PropertyOS different from another spreadsheet wearing a login screen.',
        child: _ResponsiveGrid(
          minItemWidth: 310,
          children: [
            _InfoCard(
                icon: 'AI',
                title: 'Daily AI Briefing',
                body:
                    'Start each day with a clear summary of what needs attention across your portfolio.'),
            _InfoCard(
                icon: 'D',
                title: 'Document Intelligence',
                body:
                    'Upload certificates, tenancy agreements, invoices and policies. PropertyOS extracts key facts.'),
            _InfoCard(
                icon: 'C',
                title: 'Compliance Monitoring',
                body:
                    'Track EPCs, Gas Safety Certificates, EICRs, deposit protection, Right to Rent and alarms.'),
            _InfoCard(
                icon: 'T',
                title: 'Property Timelines',
                body:
                    'Every property builds a complete operational history from documents, tasks and tenancy events.'),
            _InfoCard(
                icon: '?',
                title: 'AI Portfolio Assistant',
                body:
                    'Ask questions such as “What expires next month?” or “Summarise 14 High Street.”'),
            _InfoCard(
                icon: '→',
                title: 'Recommended Actions',
                body:
                    'PropertyOS highlights what to do next, why it matters and which evidence supports it.'),
          ],
        ),
      );
}

class _DailyBriefingShowcase extends StatelessWidget {
  const _DailyBriefingShowcase({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 84, horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.all(38),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF071827), Color(0xFF0B263B)],
              ),
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 44,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                return Flex(
                  direction: narrow ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open PropertyOS. Know what matters in under a minute.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2.6,
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'The Today view is the soul of PropertyOS: an operational briefing, not a dashboard shrine to unnecessary charts.',
                            style: TextStyle(
                                color: Color(0xFFC8D3DD), height: 1.65),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: narrow ? 0 : 30, height: narrow ? 28 : 0),
                    const Expanded(flex: 1, child: _DailyBriefingCard()),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

class _DailyBriefingCard extends StatelessWidget {
  const _DailyBriefingCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Padding(
          padding: EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning Karl.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 10),
              Text('Your portfolio is mostly healthy today.'),
              SizedBox(height: 14),
              _BriefingLine('No urgent compliance failures were found.'),
              _BriefingLine(
                  'Gas Safety Certificate for 14 High Street expires in 31 days.'),
              _BriefingLine(
                  'The tenancy at Flat 3, Victoria Court ends in 47 days.'),
              _BriefingLine('Two maintenance issues are awaiting action.'),
              _BriefingLine('Estimated monthly rent: £8,950.'),
              _BriefingLine('Estimated monthly cashflow: £4,180.'),
              SizedBox(height: 14),
              Text(
                'Recommended actions today: 3',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
}

class _AudienceSection extends StatelessWidget {
  const _AudienceSection();

  @override
  Widget build(BuildContext context) => const _PageSection(
        background: Colors.white,
        title: 'Built for independent UK landlords.',
        body:
            'PropertyOS is designed for landlords managing residential portfolios of around 5–50 properties who want less administration, fewer missed deadlines and better visibility.',
        child: _ResponsiveGrid(
          minItemWidth: 310,
          children: [
            _InfoCard(
                icon: '1',
                title: 'Professional Landlord',
                body:
                    'Runs a mature portfolio and wants confidence that nothing important has been missed.'),
            _InfoCard(
                icon: '2',
                title: 'Growing Investor',
                body:
                    'Needs systems before spreadsheets and memory become unmanageable.'),
            _InfoCard(
                icon: '3',
                title: 'Family Property Business',
                body:
                    'Wants a shared operational view across properties, documents, tasks and compliance.'),
          ],
        ),
      );
}

class _DisclaimerSection extends StatelessWidget {
  const _DisclaimerSection();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                border: Border.all(color: const Color(0xFFFED7AA)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'PropertyOS helps organise information, identify potential compliance actions and surface reminders. It does not provide legal advice and does not replace professional landlord, legal, tax or compliance advice.',
                style: TextStyle(color: Color(0xFF7C2D12), height: 1.55),
              ),
            ),
          ),
        ),
      );
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.onEnterAlpha});

  final VoidCallback onEnterAlpha;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFF071827),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 84),
        child: Column(
          children: [
            const Text(
              'Your property portfolio, understood.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 52,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -2.8,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Enter the alpha and see how PropertyOS turns landlord admin into daily intelligence.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFC8D3DD), fontSize: 18),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF071827),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              ),
              onPressed: onEnterAlpha,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Enter Alpha'),
            ),
          ],
        ),
      );
}

class _PageSection extends StatelessWidget {
  const _PageSection({
    required this.title,
    required this.body,
    required this.child,
    this.background = const Color(0xFFF6F8FB),
  });

  final String title;
  final String body;
  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        color: background,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 84),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 46,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 18,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                child,
              ],
            ),
          ),
        ),
      );
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, required this.minItemWidth});

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final count =
              (constraints.maxWidth / minItemWidth).floor().clamp(1, 4);
          final width = (constraints.maxWidth - ((count - 1) * 16)) / count;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: children
                .map((child) => SizedBox(width: width.toDouble(), child: child))
                .toList(),
          );
        },
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.icon, required this.title, required this.body});

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  icon,
                  style: const TextStyle(
                    color: Color(0xFF2F80ED),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(color: Color(0xFF667085), height: 1.5),
              ),
            ],
          ),
        ),
      );
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.title,
    required this.items,
    this.highlighted = false,
  });

  final String title;
  final List<String> items;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: highlighted ? const Color(0xFFF0FFF6) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color:
                highlighted ? const Color(0xFFBBF7D0) : const Color(0xFFE4E7EC),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        highlighted
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: highlighted
                            ? const Color(0xFF18A058)
                            : const Color(0xFF98A2B3),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                              color: Color(0xFF667085), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ],
        ),
      );
}

class _BriefingLine extends StatelessWidget {
  const _BriefingLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF18A058), size: 18),
            const SizedBox(width: 9),
            Expanded(
                child: Text(text,
                    style: const TextStyle(color: Color(0xFF667085)))),
          ],
        ),
      );
}

enum _PillTone { good, warn }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final good = tone == _PillTone.good;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFDCFAE6) : const Color(0xFFFEF0C7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: good ? const Color(0xFF067647) : const Color(0xFFB54708),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF38BDF8), Color(0xFF22C55E)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'P',
          style: TextStyle(
            color: Color(0xFF06131F),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      );
}
