import 'package:flutter/material.dart';
import '../../services/guild_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/mobile_glass_card.dart';

class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key});

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  final GuildService _guildService = GuildService();
  bool _isLoading = true;
  bool _hasGuild = false;
  
  // My Guild Data
  Map<String, dynamic>? _myGuild;
  String? _myRole;
  List<dynamic> _members = [];
  List<dynamic> _chats = [];
  
  // List of Guilds
  List<dynamic> _allGuilds = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await _guildService.getMyGuild();
    
    if (data != null && data['success'] == true) {
      if (data['has_guild'] == true) {
        _hasGuild = true;
        _myGuild = data['guild'];
        _myRole = data['my_role'];
        _members = data['members'] ?? [];
        _chats = data['chats'] ?? [];
      } else {
        _hasGuild = false;
        final listData = await _guildService.getGuilds();
        if (listData != null && listData['success'] == true) {
          _allGuilds = listData['guilds'] ?? [];
        }
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createGuild() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    
    if (name.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan deskripsi tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await _guildService.createGuild(name, desc);
    if (!mounted) return;
    if (res != null) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Berhasil')),
        );
        _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['detail'] ?? 'Gagal membuat guild')),
        );
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGuild(int guildId) async {
    setState(() => _isLoading = true);
    final res = await _guildService.joinGuild(guildId);
    if (!mounted) return;
    if (res != null) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Berhasil bergabung')),
        );
        _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['detail'] ?? 'Gagal bergabung')),
        );
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGuild() async {
    final isLeader = _myRole == 'leader';
    final actionName = isLeader ? 'Bubarkan Guild' : 'Keluar Guild';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        title: Text(actionName, style: const TextStyle(color: Colors.white)),
        content: Text(isLeader ? 'Yakin ingin membubarkan guild secara permanen?' : 'Yakin ingin keluar?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isLeader ? 'Bubarkan' : 'Keluar', style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final res = isLeader ? await _guildService.disbandGuild() : await _guildService.leaveGuild();
    if (!mounted) return;
    if (res != null) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Berhasil')),
        );
        _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['detail'] ?? 'Gagal')),
        );
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMemberAction(String action, String targetUsername) async {
    setState(() => _isLoading = true);
    Map<String, dynamic>? res;
    if (action == 'kick') {
      res = await _guildService.kickMember(targetUsername);
    } else if (action == 'promote') {
      res = await _guildService.promoteMember(targetUsername);
    } else if (action == 'demote') {
      res = await _guildService.demoteMember(targetUsername);
    } else if (action == 'transfer') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgDark,
          title: const Text('Transfer Kepemimpinan', style: TextStyle(color: Colors.white)),
          content: Text('Yakin ingin menyerahkan posisi Leader ke $targetUsername?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Transfer', style: TextStyle(color: AppColors.gold))),
          ],
        ),
      );
      if (confirm != true) {
        setState(() => _isLoading = false);
        return;
      }
      res = await _guildService.transferLeadership(targetUsername);
    }

    if (!mounted) return;
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['success'] == true ? res['message'] : (res['detail'] ?? 'Gagal'))),
      );
      if (res['success'] == true) {
        _fetchData();
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendChat() async {
    final msg = _chatController.text.trim();
    if (msg.isEmpty) return;

    _chatController.clear();
    final res = await _guildService.sendChat(msg);
    if (res != null && res['success'] == true) {
      _fetchData();
    }
  }

  Future<void> _showDonateDialog() async {
    int coins = 0;
    int gems = 0;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.bgDark,
          title: const Text('Donasi Guild', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('10 Koin = 1 EXP\n1 Gem = 20 EXP', style: TextStyle(color: Colors.white70)),
              TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Koin',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
                onChanged: (val) => coins = int.tryParse(val) ?? 0,
              ),
              TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Gems',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
                onChanged: (val) => gems = int.tryParse(val) ?? 0,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final res = await _guildService.donateToGuild(coins, gems);
                  if (res != null && res['success'] == true) {
                    _fetchData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Berhasil donasi')));
                  } else {
                    throw Exception(res?['detail'] ?? 'Gagal donasi');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Donasi', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _hasGuild ? (_myGuild?['name'] ?? 'My Guild') : '🛡️ Temukan Guild',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (_hasGuild)
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              onPressed: _leaveGuild,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1a1040)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _hasGuild
                ? _buildMyGuildView()
                : _buildGuildListView(),
      ),
    );
  }

  Widget _buildGuildListView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: MobileGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Buat Guild Baru',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nama Guild',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _createGuild,
                  child: const Text('Buat Guild (1000 Koin)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Daftar Guild',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: _allGuilds.isEmpty
              ? const Center(child: Text('Belum ada guild', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: _allGuilds.length,
                  itemBuilder: (context, index) {
                    final g = _allGuilds[index];
                    return ListTile(
                      title: Text(g['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('Level ${g['level']} • ${g['member_count']} Anggota\n${g['description']}', style: const TextStyle(color: Colors.white54)),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                        onPressed: () => _joinGuild(g['id']),
                        child: const Text('Gabung', style: TextStyle(color: Colors.black87)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMyGuildView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(Icons.shield, color: AppColors.gold, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _myGuild?['name'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Level ${_myGuild?['level']} • EXP ${_myGuild?['exp']}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.volunteer_activism, size: 16),
                        label: const Text('Donasi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: _showDonateDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Anggota', icon: Icon(Icons.people)),
              Tab(text: 'Chat', icon: Icon(Icons.chat)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMembersTab(),
                _buildChatTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return ListView.builder(
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final m = _members[index];
        final role = m['role'];
        final isLeader = role == 'leader';
        return ListTile(
          leading: Icon(
            isLeader ? Icons.star : Icons.person,
            color: isLeader ? AppColors.gold : Colors.white54,
          ),
          title: Text(m['username'], style: const TextStyle(color: Colors.white)),
          subtitle: Text('MMR: ${m['mmr_score']}', style: const TextStyle(color: Colors.white54)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                role.toString().toUpperCase(),
                style: TextStyle(
                  color: isLeader ? AppColors.gold : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (_myRole == 'leader' && !isLeader || _myRole == 'elder' && role == 'member')
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  color: AppColors.bgDark,
                  onSelected: (action) => _handleMemberAction(action, m['username']),
                  itemBuilder: (context) => [
                    if (_myRole == 'leader' && role == 'member')
                      const PopupMenuItem(value: 'promote', child: Text('Jadikan Elder', style: TextStyle(color: Colors.white))),
                    if (_myRole == 'leader' && role == 'elder')
                      const PopupMenuItem(value: 'demote', child: Text('Turunkan ke Member', style: TextStyle(color: Colors.white))),
                    if (_myRole == 'leader' && !isLeader)
                      const PopupMenuItem(value: 'transfer', child: Text('Transfer Leader', style: TextStyle(color: AppColors.gold))),
                    const PopupMenuItem(value: 'kick', child: Text('Kick dari Guild', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _chats.isEmpty
              ? const Center(child: Text('Belum ada pesan', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  reverse: true, // Karena di backend ORDER BY sent_at DESC
                  padding: const EdgeInsets.all(16),
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white12,
                            child: Icon(Icons.person, size: 16, color: Colors.white54),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(chat['username'], style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(chat['sent_at']),
                                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    chat['message'],
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black26,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF6366F1),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendChat,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
