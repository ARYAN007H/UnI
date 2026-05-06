import sys
import re

file_path = "lib/services/local_cache_service.dart"
with open(file_path, "r") as f:
    content = f.read()

# Replace initialize
content = content.replace(
    "  Future<void> initialize() async {\n    if (_db != null) return;",
    "  Future<void> initialize() async {\n    if (kIsWeb) return;\n    if (_db != null) return;"
)

# Replace all method bodies with appropriate early returns
replacements = [
    (r"(Future<void> saveMessage\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<void> saveMessages\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<List<Message>> getMessages\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return [];"),
    (r"(Future<List<Message>> getUnsyncedMessages\(\)\s*async\s*{)", r"\1\n    if (kIsWeb) return [];"),
    (r"(Future<List<Message>> getMessagesWithLocation\(\)\s*async\s*{)", r"\1\n    if (kIsWeb) return [];"),
    (r"(Future<void> markSynced\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<void> markMessagesRead\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<void> deleteMessage\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<int> getMessageCount\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return 0;"),
    (r"(Future<List<Message>> searchMessages\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return [];"),
    (r"(Future<void> saveChannels\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<List<Channel>> getChannels\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return [];"),
    (r"(Future<void> cacheMediaPath\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<String\?> getMediaLocalPath\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return null;"),
    (r"(Future<int> getCacheSize\(\)\s*async\s*{)", r"\1\n    if (kIsWeb) return 0;"),
    (r"(Future<DateTime\?> getLastSync\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return null;"),
    (r"(Future<void> setLastSync\([^)]+\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<String> getDatabasePath\(\)\s*async\s*{)", r"\1\n    if (kIsWeb) return '';"),
    (r"(Future<void> clearAll\(\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;"),
    (r"(Future<void> close\(\)\s*async\s*{)", r"\1\n    if (kIsWeb) return;")
]

for pattern, repl in replacements:
    content = re.sub(pattern, repl, content, count=1)

with open(file_path, "w") as f:
    f.write(content)

print("Done")
