import sys

with open("lib/services/local_cache_service.dart", "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    new_lines.append(line)
    if "Future<void> initialize() async {" in line:
        new_lines.append("    if (kIsWeb) { debugPrint('[LocalCache] Disabled on Web'); return; }\n")
    elif "Future<void> saveMessage(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<void> saveMessages(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<List<Message>> getMessages(" in line:
        new_lines.append("    if (kIsWeb) return [];\n")
    elif "Future<List<Message>> getUnsyncedMessages(" in line:
        new_lines.append("    if (kIsWeb) return [];\n")
    elif "Future<List<Message>> getMessagesWithLocation(" in line:
        new_lines.append("    if (kIsWeb) return [];\n")
    elif "Future<void> markSynced(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<void> markMessagesRead(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<void> deleteMessage(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<int> getMessageCount(" in line:
        new_lines.append("    if (kIsWeb) return 0;\n")
    elif "Future<List<Message>> searchMessages(" in line:
        new_lines.append("    if (kIsWeb) return [];\n")
    elif "Future<void> saveChannels(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<List<Channel>> getChannels(" in line:
        new_lines.append("    if (kIsWeb) return [];\n")
    elif "Future<void> cacheMediaPath(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<String?> getMediaLocalPath(" in line:
        new_lines.append("    if (kIsWeb) return null;\n")
    elif "Future<int> getCacheSize(" in line:
        new_lines.append("    if (kIsWeb) return 0;\n")
    elif "Future<DateTime?> getLastSync(" in line:
        new_lines.append("    if (kIsWeb) return null;\n")
    elif "Future<void> setLastSync(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<String> getDatabasePath(" in line:
        new_lines.append("    if (kIsWeb) return '';\n")
    elif "Future<void> clearAll(" in line:
        new_lines.append("    if (kIsWeb) return;\n")
    elif "Future<void> close(" in line:
        new_lines.append("    if (kIsWeb) return;\n")

with open("lib/services/local_cache_service.dart", "w") as f:
    f.writelines(new_lines)
