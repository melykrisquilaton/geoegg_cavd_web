import 'package:supabase_flutter/supabase_flutter.dart';

const productionReportPageSize = 25;

const productionReportSizes = <String, String>{
  'pw': 'PW',
  'xs': 'XS',
  's': 'S',
  'm': 'M',
  'l': 'L',
  'xl': 'XL',
  'j': 'J',
  'sj': 'SJ',
};

class ProductionReport {
  const ProductionReport({
    required this.record,
    required this.seller,
    required this.farm,
    required this.location,
    required this.review,
    required this.reviewer,
  });

  final Map<String, dynamic> record;
  final Map<String, dynamic> seller;
  final Map<String, dynamic> farm;
  final Map<String, dynamic> location;
  final Map<String, dynamic>? review;
  final Map<String, dynamic> reviewer;

  String get id => record['id'].toString();

  String get reviewStatus => (review?['review_status'] ?? 'pending').toString();

  DateTime? get collectionDate =>
      DateTime.tryParse(record['collection_date']?.toString() ?? '');

  DateTime? get reviewedAt =>
      DateTime.tryParse(review?['reviewed_at']?.toString() ?? '');

  String get sellerName => _value(seller['name'], 'Seller name unavailable');

  String get farmName => _value(
    farm['farm_name'],
    _value(location['name'], _value(record['location_name'])),
  );

  String get locationLabel {
    final parts = [
      location['barangay'],
      location['city'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty);
    final address = parts.join(', ');
    return address.isEmpty ? _value(record['location_name']) : address;
  }

  static String _value(dynamic value, [String fallback = 'Not provided']) {
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }
}

class ProductionReportsPage {
  const ProductionReportsPage({
    required this.reports,
    required this.totalCount,
  });

  final List<ProductionReport> reports;
  final int totalCount;
}

class ProductionReportRepository {
  ProductionReportRepository(this._client);

  final SupabaseClient _client;

  static const _reportColumns = '''
    id, seller_id, location_id, location_name, collection_date,
    record_status, confirmed_at, created_at, updated_at,
    qty_pw, qty_xs, qty_s, qty_m, qty_l, qty_xl, qty_j, qty_sj,
    damaged_pw, damaged_xs, damaged_s, damaged_m, damaged_l,
    damaged_xl, damaged_j, damaged_sj,
    weight_pw_kg, weight_xs_kg, weight_s_kg, weight_m_kg,
    weight_l_kg, weight_xl_kg, weight_j_kg, weight_sj_kg,
    seller:profiles!production_records_seller_id_fkey(
      name, email, contact_number,
      farm:producer_profiles!producer_profiles_user_id_fkey(
        farm_name, owner_name
      )
    ),
    location:locations!production_records_location_id_fkey(
      name, barangay, city, address
    ),
    current_review:production_report_reviews!production_report_reviews_production_record_id_fkey(
      review_status, review_note, reviewed_by, reviewed_at,
      reviewer:profiles!production_report_reviews_reviewed_by_fkey(name)
    ),
    seller_search:profiles!production_records_seller_id_fkey(),
    farm_search:profiles!production_records_seller_id_fkey(
      producer_search:producer_profiles!producer_profiles_user_id_fkey()
    ),
    location_search:locations!production_records_location_id_fkey(),
    review_filter:production_report_reviews!production_report_reviews_production_record_id_fkey()
  ''';

  Future<bool> currentUserIsAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    return profile?['role']?.toString().toLowerCase() == 'admin';
  }

  Future<ProductionReportsPage> loadPage({
    required int page,
    required String searchText,
    required String reviewStatus,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    var query = _client
        .from('production_records')
        .select(_reportColumns)
        .eq('record_status', 'complete');

    String dateOnly(DateTime date) {
      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');

      return '$year-$month-$day';
    }

    if (dateFrom != null) {
      final start = DateTime(
        dateFrom.year,
        dateFrom.month,
        dateFrom.day,
      );

      query = query.gte(
        'collection_date',
        dateOnly(start),
      );
    }

    if (dateTo != null) {
      final afterEnd = DateTime(
        dateTo.year,
        dateTo.month,
        dateTo.day + 1,
      );

      query = query.lt(
        'collection_date',
        dateOnly(afterEnd),
      );
    }

    if (reviewStatus == 'pending') {
      // A missing current-review row represents Pending. This embedded null
      // filter performs the anti-join in PostgreSQL before pagination.
      query = query.isFilter('review_filter', null);
    } else if (reviewStatus != 'all') {
      query = query
          .eq('review_filter.review_status', reviewStatus)
          .not('review_filter', 'is', null);
    }

    final search = searchText.trim();
    if (search.isNotEmpty) {
      final pattern = _ilikePattern(search);
      final searchClauses = <String>[
        'location_name.ilike.$pattern',
        'seller_search.not.is.null',
        'farm_search.producer_search.not.is.null',
        'location_search.not.is.null',
      ];
      if (_uuidPattern.hasMatch(search)) {
        searchClauses.add('id.eq.$search');
      }
      query = query
          .or(
            'name.ilike.$pattern,email.ilike.$pattern',
            referencedTable: 'seller_search',
          )
          .or(
            'farm_name.ilike.$pattern,owner_name.ilike.$pattern',
            referencedTable: 'farm_search.producer_search',
          )
          .or(
            'name.ilike.$pattern,barangay.ilike.$pattern,city.ilike.$pattern',
            referencedTable: 'location_search',
          )
          .or(searchClauses.join(','));
    }

    final response = await query
        .order('collection_date', ascending: false)
        .order('id', ascending: false)
        .range(
          page * productionReportPageSize,
          page * productionReportPageSize + productionReportPageSize - 1,
        )
        .count(CountOption.exact);

    return ProductionReportsPage(
      totalCount: response.count,
      reports: response.data.map(_toReport).toList(),
    );
  }

  ProductionReport _toReport(Map<String, dynamic> row) {
    final record = Map<String, dynamic>.from(row);
    final seller = _embeddedMap(record['seller']);
    final farm = _embeddedMap(seller['farm']);
    final location = _embeddedMap(record['location']);
    final rawReview = record['current_review'];
    final review = rawReview == null ? null : _embeddedMap(rawReview);
    final reviewer = _embeddedMap(review?['reviewer']);

    return ProductionReport(
      record: record,
      seller: seller,
      farm: farm,
      location: location,
      review: review,
      reviewer: reviewer,
    );
  }

  Map<String, dynamic> _embeddedMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  String _ilikePattern(String term) {
    final escaped = term
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_')
        .replaceAll('"', r'\"');
    return '"%$escaped%"';
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<List<Map<String, dynamic>>> loadHistory(String recordId) async {
    final rows = await _client
        .from('production_report_review_history')
        .select(
          'id, production_record_id, review_status, review_note, '
          'reviewed_by, reviewed_at',
        )
        .eq('production_record_id', recordId)
        .order('reviewed_at', ascending: false)
        .order('id', ascending: false);

    final history = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    final reviewerIds = history
        .map((row) => row['reviewed_by']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (reviewerIds.isEmpty) return history;

    final reviewers = await _client
        .from('profiles')
        .select('id, name')
        .inFilter('id', reviewerIds);
    final namesById = {
      for (final row in reviewers)
        row['id'].toString(): row['name']?.toString() ?? 'Administrator',
    };

    return [
      for (final item in history)
        {
          ...item,
          'reviewer_name':
              namesById[item['reviewed_by'].toString()] ?? 'Administrator',
        },
    ];
  }

  Future<void> submitReview({
    required String recordId,
    required String status,
    required String? note,
  }) async {
    await _client.rpc(
      'review_production_report',
      params: {
        'p_production_record_id': recordId,
        'p_review_status': status,
        'p_review_note': note,
      },
    );
  }
}
