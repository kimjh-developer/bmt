import sys

with open('lib/ui/tracker/tracker_page.dart', 'r') as f:
    lines = f.readlines()

new_content = """        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1B2028).withOpacity(0.9),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: const Color(0xFF44484F).withOpacity(0.3)),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('메모 남기기', style: GoogleFonts.notoSansKr(color: const Color(0xFFF1F3FC), fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('기록은 기억보다 오래갑니다.', style: GoogleFonts.notoSansKr(color: const Color(0xFF6DDDFF), fontSize: 14)),
              ],
            ),
            content: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F141A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF44484F).withOpacity(0.5)),
              ),
              child: TextField(
                controller: commentController,
                maxLines: 4,
                style: GoogleFonts.notoSansKr(color: const Color(0xFFF1F3FC), fontSize: 14, height: 1.5),
                decoration: InputDecoration(
                  hintText: '이 순간을 기록해보세요...',
                  hintStyle: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.only(right: 20, bottom: 20, top: 10),
            actions: [
              TextButton(
                onPressed: () {
                  comment = null;
                  Navigator.pop(context);
                },
                child: Text('건너뛰기', style: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3), fontSize: 15)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  comment = commentController.text;
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6DDDFF),
                  foregroundColor: const Color(0xFF002C37),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('저장', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        );"""

# Replace lines 505-536 (0-indexed 505 to 536)
lines[505:537] = [l + '\n' for l in new_content.split('\n')]
# Also replace line 503 to add barrierColor:
lines[502] = "      barrierColor: Colors.black.withOpacity(0.5),\n" + lines[502]

with open('lib/ui/tracker/tracker_page.dart', 'w') as f:
    f.writelines(lines)

