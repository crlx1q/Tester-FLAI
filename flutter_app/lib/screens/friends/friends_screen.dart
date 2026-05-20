import 'package:flutter/material.dart';
import '../../utils/api_helper.dart';
import 'friend_progress_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriends();
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    final result = await ApiHelper.getFriends();
    if (mounted && result['success']) {
      setState(() {
        _friends = List<Map<String, dynamic>>.from(result['friends'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRequests() async {
    final result = await ApiHelper.getFriendRequests();
    if (mounted && result['success']) {
      setState(() {
        _requests = List<Map<String, dynamic>>.from(result['requests'] ?? []);
        _requestCount = _requests.length;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final result = await ApiHelper.searchFriends(query);
    if (mounted && result['success']) {
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(result['users'] ?? []);
        _isSearching = false;
      });
    } else {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(String userId) async {
    final result = await ApiHelper.sendFriendRequest(userId);
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запрос отправлен'), backgroundColor: Colors.green),
        );
        _searchUsers(_searchController.text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Ошибка'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _acceptRequest(String friendshipId) async {
    final result = await ApiHelper.acceptFriendRequest(friendshipId);
    if (mounted && result['success']) {
      _loadRequests();
      _loadFriends();
    }
  }

  Future<void> _rejectRequest(String friendshipId) async {
    final result = await ApiHelper.rejectFriendRequest(friendshipId);
    if (mounted && result['success']) {
      _loadRequests();
    }
  }

  String _getGoalText(String? goal) {
    switch (goal) {
      case 'lose_weight': return 'Похудение';
      case 'gain_muscle': return 'Набор массы';
      case 'maintain': return 'Поддержание';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Друзья', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Друзья'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Запросы'),
                  if (_requestCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_requestCount',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Поиск'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(isDark),
          _buildRequestsList(isDark),
          _buildSearchTab(isDark),
        ],
      ),
    );
  }

  Widget _buildFriendsList(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: isDark ? Colors.white38 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'Пока нет друзей',
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(height: 8),
            Text(
              'Найдите друзей по @username',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return _buildFriendTile(friend, isDark);
        },
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          child: Text(
            (friend['name'] ?? '?')[0].toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        title: Text(
          friend['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (friend['username'] != null)
              Text('@${friend['username']}', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13)),
            if (friend['goal'] != null)
              Text(_getGoalText(friend['goal']), style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (friend['streak'] != null && friend['streak'] > 0) ...[
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
              Text('${friend['streak']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FriendProgressScreen(
                friendId: friend['_id'],
                friendName: friend['name'] ?? '',
                friendUsername: friend['username'],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList(bool isDark) {
    if (_requests.isEmpty) {
      return Center(
        child: Text(
          'Нет входящих запросов',
          style: TextStyle(fontSize: 15, color: isDark ? Colors.white54 : Colors.black45),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              child: Text(
                (req['name'] ?? '?')[0].toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ),
            title: Text(req['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: req['username'] != null
                ? Text('@${req['username']}', style: const TextStyle(fontSize: 13))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _acceptRequest(req['friendshipId']),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _rejectRequest(req['friendshipId']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск по @username...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            ),
            onChanged: (value) => _searchUsers(value),
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return _buildSearchResultTile(user, isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> user, bool isDark) {
    final status = user['friendStatus'] ?? 'none';
    
    Widget trailing;
    switch (status) {
      case 'friends':
        trailing = const Chip(label: Text('Друзья', style: TextStyle(fontSize: 12)));
        break;
      case 'sent':
        trailing = const Chip(label: Text('Отправлено', style: TextStyle(fontSize: 12)));
        break;
      case 'received':
        trailing = TextButton(
          onPressed: () {
            _tabController.animateTo(1);
            _loadRequests();
          },
          child: const Text('Принять'),
        );
        break;
      default:
        trailing = IconButton(
          icon: const Icon(Icons.person_add, color: Colors.blue),
          onPressed: () => _sendRequest(user['_id']),
        );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          child: Text(
            (user['name'] ?? '?')[0].toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        title: Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('@${user['username'] ?? ''}', style: const TextStyle(fontSize: 13)),
        trailing: trailing,
      ),
    );
  }
}
