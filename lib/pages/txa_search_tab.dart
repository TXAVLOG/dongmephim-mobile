import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_api.dart';
import 'txa_movie_detail_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TxaApi _api = TxaApi();

  Timer? _debounceTimer;
  bool _isLoading = false;
  bool _isMoreLoading = false;
  bool _isFilterExpanded = false;
  String _query = '';

  // Pagination states
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalResults = 0;

  // Filter selections
  String? _selectedType;
  String? _selectedCategory;
  String? _selectedRegion;
  String? _selectedYear;

  // Metadata lists
  List<dynamic> _hotKeywords = [];
  List<dynamic> _categories = [];
  List<dynamic> _regions = [];
  List<String> _years = [];
  bool _isLoadingFilters = false;

  // Results list
  List<dynamic> _movies = [];

  @override
  void initState() {
    super.initState();
    _fetchHotSearches();
    _fetchFilters();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Fetch trending searches
  Future<void> _fetchHotSearches() async {
    final list = await _api.getHotSearches();
    if (mounted) {
      setState(() {
        _hotKeywords = list;
      });
    }
  }

  // Fetch filters metadata
  Future<void> _fetchFilters() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFilters = true;
    });

    final data = await _api.getFilters();
    if (mounted) {
      setState(() {
        if (data != null) {
          _categories = data['categories'] as List<dynamic>? ?? [];
          _regions = data['regions'] as List<dynamic>? ?? [];
          final yearsRaw = data['years'] as List<dynamic>? ?? [];
          _years = yearsRaw.map((y) => y.toString()).toList();
        }
        _isLoadingFilters = false;
      });
    }
  }

  // Infinite Scroll Listener
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 200.0;

    if (maxScroll - currentScroll <= threshold &&
        !_isLoading &&
        !_isMoreLoading &&
        _currentPage < _lastPage) {
      _loadMoreMovies();
    }
  }

  // Trigger search with query and active filters
  Future<void> _executeSearch({bool isNewSearch = true}) async {
    if (!mounted) return;

    if (isNewSearch) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _movies.clear();
      });
    } else {
      setState(() {
        _isMoreLoading = true;
      });
    }

    final data = await _api.searchMovies(
      _query,
      page: _currentPage,
      category: _selectedCategory,
      region: _selectedRegion,
      year: _selectedYear,
      type: _selectedType,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isMoreLoading = false;

        if (data != null) {
          final results = data['data'] as List<dynamic>? ?? [];
          if (isNewSearch) {
            _movies = results;
          } else {
            _movies.addAll(results);
          }

          final pag = data['pagination'];
          if (pag != null) {
            _totalResults = int.tryParse(pag['total'].toString()) ?? _movies.length;
            _lastPage = int.tryParse(pag['last_page'].toString()) ?? 1;
          } else {
            _totalResults = _movies.length;
            _lastPage = 1;
          }
        }
      });
    }
  }

  // Load next page of movies
  Future<void> _loadMoreMovies() async {
    _currentPage++;
    await _executeSearch(isNewSearch: false);
  }

  // Input debouncing helper
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _query = value.trim();
        });
        _executeSearch(isNewSearch: true);
      }
    });
  }

  // Perform search immediately (when pressing enter or selecting keyword)
  void _performImmediateSearch(String keyword) {
    final cleanKeyword = keyword.trim();
    _debounceTimer?.cancel();
    _searchController.text = cleanKeyword;
    FocusScope.of(context).unfocus();
    setState(() {
      _query = cleanKeyword;
    });
    _executeSearch(isNewSearch: true);
    if (cleanKeyword.isNotEmpty) {
      _api.registerSearchClick(cleanKeyword);
    }
  }

  // Reset filters
  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedCategory = null;
      _selectedRegion = null;
      _selectedYear = null;
    });
    _executeSearch(isNewSearch: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Provider.of<TxaLanguage>(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header Spacer
          SizedBox(height: topPadding + 12),

          // Search Bar & Filter Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Glassmorphic Search Input field
                Expanded(
                  child: TxaTheme.liquidGlassPill(
                    radius: 16,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              color: TxaTheme.textSecondary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              onSubmitted: _performImmediateSearch,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: TxaLanguage.t('search_hint'),
                                hintStyle: const TextStyle(
                                    color: TxaTheme.textMuted, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: Colors.white70, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                });
                                _executeSearch(isNewSearch: true);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Filter Panel Toggle Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isFilterExpanded = !_isFilterExpanded;
                    });
                  },
                  child: TxaTheme.liquidGlassPill(
                    radius: 16,
                    borderGlowColor: _isFilterExpanded ? TxaTheme.accent : null,
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      child: Icon(
                        _isFilterExpanded
                            ? Icons.filter_list_off_rounded
                            : Icons.filter_list_rounded,
                        color: _isFilterExpanded ? TxaTheme.accent : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Collapsible Filters Panel
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterPanel(),
            crossFadeState: _isFilterExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),

          // Main Search content Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: TxaTheme.accent),
                  )
                : (_query.isEmpty &&
                        _selectedType == null &&
                        _selectedCategory == null &&
                        _selectedRegion == null &&
                        _selectedYear == null)
                    ? _buildTrendingSection()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  // Filter Panel Builder
  Widget _buildFilterPanel() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0),
      child: TxaTheme.liquidGlassPill(
        radius: 20,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bộ lọc tìm kiếm',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                GestureDetector(
                  onTap: _clearFilters,
                  child: Text(
                    TxaLanguage.t('clear_filter'),
                    style: const TextStyle(
                        color: TxaTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Type Filter (Phim bộ / Phim lẻ)
            _buildFilterRow(
              title: 'Loại hình',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('Tất cả', null, _selectedType, (val) {
                    setState(() => _selectedType = val);
                    _executeSearch(isNewSearch: true);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip(TxaLanguage.t('movie_series'), 'series',
                      _selectedType, (val) {
                    setState(() => _selectedType = val);
                    _executeSearch(isNewSearch: true);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip(TxaLanguage.t('movie_single'), 'single',
                      _selectedType, (val) {
                    setState(() => _selectedType = val);
                    _executeSearch(isNewSearch: true);
                  }),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 16),

            // Category Filter
            _buildFilterRow(
              title: 'Thể loại',
              child: _isLoadingFilters
                  ? const SizedBox(
                      height: 32,
                      child: Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: TxaTheme.accent))),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                          _buildFilterChip('Tất cả', null, _selectedCategory,
                              (val) {
                            setState(() => _selectedCategory = val);
                            _executeSearch(isNewSearch: true);
                          }),
                          ..._categories.map((c) {
                            final slug = c['slug'] as String;
                            final name = c['name'] as String;
                            return _buildFilterChip(
                                name, slug, _selectedCategory, (val) {
                              setState(() => _selectedCategory = val);
                              _executeSearch(isNewSearch: true);
                            });
                          }),
                        ],
                      ),
            ),
            const Divider(color: Colors.white10, height: 16),

            // Region Filter
            _buildFilterRow(
              title: 'Quốc gia',
              child: _isLoadingFilters
                  ? const SizedBox(
                      height: 32,
                      child: Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: TxaTheme.accent))),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                          _buildFilterChip('Tất cả', null, _selectedRegion,
                              (val) {
                            setState(() => _selectedRegion = val);
                            _executeSearch(isNewSearch: true);
                          }),
                          ..._regions.map((r) {
                            final slug = r['slug'] as String;
                            final name = r['name'] as String;
                            return _buildFilterChip(
                                name, slug, _selectedRegion, (val) {
                              setState(() => _selectedRegion = val);
                              _executeSearch(isNewSearch: true);
                            });
                          }),
                        ],
                      ),
            ),
            const Divider(color: Colors.white10, height: 16),

            // Year Filter
            _buildFilterRow(
              title: 'Năm chiếu',
              child: _isLoadingFilters
                  ? const SizedBox(
                      height: 32,
                      child: Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: TxaTheme.accent))),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                          _buildFilterChip('Tất cả', null, _selectedYear,
                              (val) {
                            setState(() => _selectedYear = val);
                            _executeSearch(isNewSearch: true);
                          }),
                          ..._years.map((y) {
                            return _buildFilterChip(y, y, _selectedYear, (val) {
                              setState(() => _selectedYear = val);
                              _executeSearch(isNewSearch: true);
                            });
                          }),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              color: TxaTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildFilterChip(String label, String? value, String? groupValue,
      Function(String?) onSelected) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isSelected ? TxaTheme.brandGradient : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: isSelected
                ? TxaTheme.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : TxaTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Hot Searches / Trending List
  Widget _buildTrendingSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                TxaLanguage.t('search_hot_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_hotKeywords.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Không có từ khóa hot nào',
                  style: TextStyle(color: TxaTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _hotKeywords.map((item) {
                    final kw = item['keyword'] as String;
                    final clicks = item['clicks'] as int? ?? 0;

                    return GestureDetector(
                      onTap: () => _performImmediateSearch(kw),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: clicks > 50
                              ? const LinearGradient(colors: [Colors.orange, Colors.red])
                              : LinearGradient(colors: [TxaTheme.cardBg.withValues(alpha: 0.8), TxaTheme.cardBg]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: clicks > 50 ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                          boxShadow: clicks > 50 ? [
                            BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)
                          ] : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kw,
                              style: TextStyle(
                                  color: clicks > 50 ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: clicks > 50 ? FontWeight.bold : FontWeight.w500),
                            ),
                            if (clicks > 20) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: clicks > 50 ? Colors.white : Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'HOT',
                                  style: TextStyle(
                                    color: clicks > 50 ? Colors.red : Colors.redAccent[100],
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Search Results view
  Widget _buildSearchResults() {
    if (_movies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: TxaTheme.liquidGlassPill(
            radius: 20,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded,
                    color: TxaTheme.textMuted, size: 48),
                const SizedBox(height: 16),
                Text(
                  TxaLanguage.t('search_no_results')
                      .replaceAll('%query%', _query),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hãy thử tìm kiếm với từ khóa khác hoặc xóa bớt các bộ lọc đang chọn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: TxaTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _clearFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TxaTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(TxaLanguage.t('clear_filter')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final resultsTitle = TxaLanguage.t('search_results')
        .replaceAll('%count%', _totalResults.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results Count Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            resultsTitle,
            style: const TextStyle(
              color: TxaTheme.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Grid View of Movies
        Builder(builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final crossAxisCount = (screenWidth / 110).floor().clamp(3, 8);

          return Expanded(
            child: GridView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 90),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 120 / 210,
                crossAxisSpacing: 6,
                mainAxisSpacing: 10,
              ),
              itemCount: _movies.length + (_isMoreLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _movies.length) {
                  return const Center(
                    child: CircularProgressIndicator(color: TxaTheme.accent),
                  );
                }

                final movie = _movies[index];
                return _buildMovieGridCard(movie);
              },
            ),
          );
        }),
      ],
    );
  }

  // Movie Card matching HomeScreen theme
  Widget _buildMovieGridCard(dynamic movie) {
    final posterUrl = movie['poster_url'] ?? movie['thumb_url'] ?? '';
    final name = movie['name'] ?? '';
    final originName = movie['origin_name'] ?? '';
    final episode = movie['episode_current'] ?? 'Full';
    final quality = movie['quality'] ?? 'FHD';
    final year = movie['year']?.toString() ?? '';
    final lang = movie['lang'] ?? 'Vietsub';

    // Rating score
    dynamic tmdbVote = movie['tmdb']?['vote_average'];
    dynamic imdbVote = movie['imdb']?['vote_average'];
    String imdbScore = (tmdbVote ?? imdbVote ?? '').toString();

    return GestureDetector(
      onTap: () {
        // Track click on backend
        if (_query.isNotEmpty) {
          _api.registerSearchClick(_query, movieId: movie['id']);
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MovieDetailScreen(slug: movie['slug'] ?? ''),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie Poster inside Liquid Glass card
            TxaTheme.liquidGlassPill(
              radius: 16,
              child: AspectRatio(
                aspectRatio: 120 / 160,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              Container(color: TxaTheme.cardBg),
                        ),
                      ),
                    ),
                    // Combined Badges Row (Top Left & Top Right)
                    Positioned(
                      top: 6,
                      left: 6,
                      right: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                episode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: TxaTheme.accent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              quality,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom bar gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.95),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Year Tag (Bottom Left)
                    if (year.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            year,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // Language Tag (Bottom Right)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          lang,
                          style: const TextStyle(
                            color: TxaTheme.textSecondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // IMDb rating (Bottom Center)
                    if (imdbScore.isNotEmpty &&
                        imdbScore != '0' &&
                        imdbScore != '0.0')
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.black, size: 7),
                                const SizedBox(width: 1.5),
                                Text(
                                  imdbScore,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
            ),
            if (originName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  originName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
