
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UsersScreen extends StatefulWidget {
  final String initialFilter;

  const UsersScreen({
    super.key,
    this.initialFilter = 'all',
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final supabase = Supabase.instance.client;

  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();

    const validFilters = ['all', 'buyer', 'seller'];

    _selectedFilter = validFilters.contains(widget.initialFilter)
        ? widget.initialFilter
        : 'all';
  }
  
  final Set<String> _approvalsInProgress = {};

  static const cream = Color(0xFFFFF8F4);
  static const peach = Color(0xFFFBE3D5);
  static const orange = Color(0xFFE96B32);
  static const darkBrown = Color(0xFF3D3029);
  static const muted = Color(0xFF887A72);

  late final Stream<List<Map<String, dynamic>>> _users = supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  bool _matchesFilter(Map<String, dynamic> data) {
    final role = (data['role'] ?? '').toString().toLowerCase();

    if (_selectedFilter == 'all') {
      return role == 'buyer' || role == 'seller';
    }

    return role == _selectedFilter;
  }

  String _sellerStatus(Map<String, dynamic> data) {
    if ((data['role'] ?? '').toString().toLowerCase() != 'seller') {
      return '';
    }

    return (data['seller_status'] ?? 'pending')
        .toString()
        .toLowerCase();
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'buyer':
        return Colors.blue;
      case 'seller':
        return orange;
      default:
        return muted;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return orange;
      default:
        return muted;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty
            ? '—'
            : status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _roleChip(String role) {
    final color = _roleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.isEmpty
            ? 'Unknown'
            : role[0].toUpperCase() + role.substring(1),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _userAvatar(Map<String, dynamic> data) {
    final role = (data['role'] ?? '').toString().toLowerCase();
    final color = _roleColor(role);
    final photoPath = data['photo_path']?.toString().trim() ?? '';

    Widget fallback() {
      return CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          role == 'seller'
              ? Icons.storefront_outlined
              : Icons.person_outline,
          color: color,
        ),
      );
    }

    if (photoPath.isEmpty) return fallback();

    return FutureBuilder<String>(
      future: supabase.storage
          .from('avatars')
          .createSignedUrl(photoPath, 3600),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return fallback();
        }

        return CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.12),
          backgroundImage: NetworkImage(snapshot.data!),
        );
      },
    );
  }

  Widget _filterButton(String value, String label) {
    final selected = _selectedFilter == value;

    return OutlinedButton(
      onPressed: () {
        setState(() => _selectedFilter = value);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? peach : Colors.white,
        foregroundColor: selected ? orange : muted,
        side: BorderSide(
          color: selected ? orange : const Color(0xFFE8DCD4),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _updateSellerStatus({
    required String userId,
    required String newStatus,
  }) async {
    if (newStatus == 'approved' &&
        _approvalsInProgress.contains(userId)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        if (newStatus == 'approved') {
          return _ApprovalDialog(
            onCancel: () => Navigator.pop(dialogContext, false),
            onConfirm: () => Navigator.pop(dialogContext, true),
          );
        }

        return AlertDialog(
          title: const Text('Reject Seller'),
          content: const Text(
            'Are you sure you want to reject this seller?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    if (newStatus == 'approved' &&
        !_approvalsInProgress.add(userId)) {
      return;
    }

    try {
      await supabase.rpc(
        'set_seller_status',
        params: {
          'p_seller_id': userId,
          'p_status': newStatus,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'approved'
                ? 'Seller approved successfully.'
                : 'Seller rejected successfully.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('SELLER STATUS ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update seller status. Please check your permissions and try again.',
          ),
        ),
      );
    } finally {
      _approvalsInProgress.remove(userId);
    }
  }

  void _showUserDetails(Map<String, dynamic> data) {
    final userId = (data['id'] ?? '').toString();
    final name = (data['name'] ?? 'Unknown user').toString();
    final email = (data['email'] ?? 'No email').toString();
    final role = (data['role'] ?? 'unknown').toString().toLowerCase();
    final status = _sellerStatus(data);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'User Details',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: darkBrown,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    _detailRow('Name', name),
                    _detailRow('Email', email),
                    _detailRow('Role', role.toUpperCase()),
                    if (role == 'seller')
                      _detailRow('Seller Status', status.toUpperCase()),
                    _detailRow('User ID', userId),
                    if (role == 'seller') ...[
                      const Divider(height: 30),
                      VerificationDocumentsSection(sellerId: userId),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        if (role == 'seller' && status == 'pending')
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _updateSellerStatus(
                                userId: userId,
                                newStatus: 'rejected',
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Reject'),
                          ),
                        if (role == 'seller' &&
                            (status == 'pending' || status == 'rejected'))
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _updateSellerStatus(
                                userId: userId,
                                newStatus: 'approved',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve'),
                          ),
                        if (role == 'seller' && status == 'approved')
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _updateSellerStatus(
                                userId: userId,
                                newStatus: 'rejected',
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Reject'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              color: darkBrown,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _userTable(List<Map<String, dynamic>> users) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF0E5DE)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(cream),
          columnSpacing: 35,
          horizontalMargin: 22,
          columns: const [
            DataColumn(label: Text('USER')),
            DataColumn(label: Text('EMAIL')),
            DataColumn(label: Text('ROLE')),
            DataColumn(label: Text('SELLER STATUS')),
            DataColumn(label: Text('ACTION')),
          ],
          rows: users.map((data) {
            final name = (data['name'] ?? 'Unknown user').toString();
            final email = (data['email'] ?? 'No email').toString();
            final role = (data['role'] ?? '').toString().toLowerCase();
            final status = _sellerStatus(data);

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 170,
                    child: Row(
                      children: [
                        _userAvatar(data),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: darkBrown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 190,
                    child: Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_roleChip(role)),
                DataCell(
                  role == 'seller'
                      ? _statusChip(status)
                      : const Text('—'),
                ),
                DataCell(
                  TextButton.icon(
                    onPressed: () => _showUserDetails(data),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View details'),
                    style: TextButton.styleFrom(
                      foregroundColor: orange,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _users,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: orange),
          );
        }

        if (snapshot.hasError) {
          debugPrint('USERS STREAM ERROR: ${snapshot.error}');

          return const Center(
            child: Text(
              'Unable to load users. Please check your connection and permissions.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final documents =
            snapshot.data ?? <Map<String, dynamic>>[];

        final filteredUsers = documents
            .where(_matchesFilter)
            .toList();

        final pendingSellers = documents.where((data) {
          return (data['role'] ?? '').toString().toLowerCase() ==
                  'seller' &&
              _sellerStatus(data) == 'pending';
        }).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Management',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'View registered GeoEgg users and review seller applications.',
                style: TextStyle(color: muted, fontSize: 14),
              ),
              const SizedBox(height: 25),

              if (pendingSellers > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: peach,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions,
                        color: orange,
                        size: 25,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          '$pendingSellers seller '
                          '${pendingSellers == 1 ? 'application is' : 'applications are'} waiting for review.',
                          style: const TextStyle(
                            color: darkBrown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 22),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _filterButton('all', 'All'),
                  _filterButton('buyer', 'Buyers'),
                  _filterButton('seller', 'Sellers'),
                ],
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  const Icon(Icons.people_outline, color: orange),
                  const SizedBox(width: 9),
                  Text(
                    '${filteredUsers.length} ${filteredUsers.length == 1 ? 'user' : 'users'}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              if (filteredUsers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 55,
                        color: muted,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: darkBrown,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _selectedFilter == 'all'
                            ? 'There are no registered users yet.'
                            : 'There are no $_selectedFilter accounts yet.',
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                )
              else
                _userTable(filteredUsers),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  static const orange = Color(0xFFE96B32);

  bool _hasConfirmedReview = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Seller Approval'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Have you reviewed the verification documents and confirmed that this applicant is a legitimate registered egg producer?',
            ),
            const SizedBox(height: 15),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _hasConfirmedReview,
              onChanged: (value) {
                setState(() {
                  _hasConfirmedReview = value ?? false;
                });
              },
              title: const Text(
                "I confirm that I have reviewed the registration proof and verified this Seller's eligibility.",
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _hasConfirmedReview ? widget.onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm Approval'),
        ),
      ],
    );
  }
}

class VerificationDocumentsSection extends StatefulWidget {
  const VerificationDocumentsSection({
    super.key,
    required this.sellerId,
  });

  final String sellerId;

  @override
  State<VerificationDocumentsSection> createState() =>
      _VerificationDocumentsSectionState();
}

class _VerificationDocumentsSectionState
    extends State<VerificationDocumentsSection> {

  static const cream = Color(0xFFFFF8F4);
  static const orange = Color(0xFFE96B32);
  static const darkBrown = Color(0xFF3D3029);
  static const muted = Color(0xFF887A72);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _openingDocumentId;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rows = await supabase
          .from('verification_documents')
          .select(
            'id, document_type, storage_path, file_name, status, review_note, uploaded_at',
          )
          .eq('seller_id', widget.sellerId)
          .order('uploaded_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _documents = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('VERIFICATION DOCUMENT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load verification documents. Please retry.';
      });
    }
  }

  Future<void> _viewDocument(
    Map<String, dynamic> document,
  ) async {
    if (_openingDocumentId != null) return;

    final documentId = document['id']?.toString() ?? '';
    final storagePath =
        document['storage_path']?.toString().trim() ?? '';

    if (documentId.isEmpty || storagePath.isEmpty) {
      setState(() {
        _errorMessage = 'This document has no valid storage path.';
      });
      return;
    }

    setState(() {
      _openingDocumentId = documentId;
      _errorMessage = null;
    });

    try {
      final signedUrl = await supabase.storage
          .from('verification-docs')
          .createSignedUrl(storagePath, 300);

      if (!mounted) return;

      final opened = await launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!opened) {
        setState(() {
          _errorMessage = 'Unable to open the verification document.';
        });
      }
    } catch (e) {
      debugPrint('DOCUMENT OPEN ERROR: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Unable to create a secure document link or open it.';
      });
    } finally {
      if (mounted) {
        setState(() => _openingDocumentId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Verification Documents',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh documents',
              onPressed: _isLoading || _openingDocumentId != null
                  ? null
                  : _loadDocuments,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_isLoading && _documents.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: orange),
            ),
          )
        else ...[
          if (_isLoading) const LinearProgressIndicator(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (!_isLoading && _documents.isEmpty && _errorMessage == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Text(
                'No verification documents found for this seller.',
                style: TextStyle(color: muted),
              ),
            ),
          ..._documents.map((document) {
            final documentId = document['id']?.toString() ?? '';
            final status =
                (document['status'] ?? 'unknown').toString();
            final reviewNote =
                document['review_note']?.toString().trim() ?? '';
            final isOpening = _openingDocumentId == documentId;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF0E5DE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (document['document_type'] ?? 'Document').toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    (document['file_name'] ?? 'Unnamed file').toString(),
                  ),
                  const SizedBox(height: 7),
                  Text('Status: $status'),
                  if (reviewNote.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text('CAVD remarks: $reviewNote'),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openingDocumentId == null
                        ? () => _viewDocument(document)
                        : null,
                    icon: isOpening
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.open_in_new),
                    label: const Text('View document'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: orange,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
