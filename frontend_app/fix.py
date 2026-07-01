import os
import re

lib_dir = "lib"

# 1. Delete duplicate old files
old_files = [
    "screens/dashboard_screen.dart",
    "screens/game_screen.dart",
    "screens/server_setup_screen.dart",
    "screens/login_screen.dart",
    "screens/register_screen.dart"
]
for f in old_files:
    path = os.path.join(lib_dir, f)
    if os.path.exists(path):
        os.remove(path)

# 2. Fix dashboard imports
dash_path = os.path.join(lib_dir, "screens", "dashboard", "dashboard_screen.dart")
if os.path.exists(dash_path):
    with open(dash_path, "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("import '../practice_screen.dart';", "import '../practice/practice_screen.dart';")
    content = content.replace("import '../shop_screen.dart';", "import '../shop/shop_screen.dart';")
    content = content.replace("import '../inventory_screen.dart';", "import '../inventory/inventory_screen.dart';")
    with open(dash_path, "w", encoding="utf-8") as f:
        f.write(content)

# 3. Fix service imports in new paths
def fix_service_import(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    # Change '../services/' to '../../services/'
    content = content.replace("import '../services/", "import '../../services/")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

fix_service_import(os.path.join(lib_dir, "screens", "practice", "practice_screen.dart"))
fix_service_import(os.path.join(lib_dir, "screens", "shop", "shop_screen.dart"))
fix_service_import(os.path.join(lib_dir, "screens", "inventory", "inventory_screen.dart"))
fix_service_import(os.path.join(lib_dir, "screens", "shop", "item_detail_screen.dart"))

# 4. Fix riverpod imports in providers
def fix_riverpod(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    if "flutter_riverpod" not in content:
        content = "import 'package:flutter_riverpod/flutter_riverpod.dart';\n" + content
    
    # Wait, error: `Classes can only extend other classes - lib\providers\profile_provider.dart:7:31 - extends_non_class`
    # That means `StateNotifier` is not found, which is from flutter_riverpod.
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

fix_riverpod(os.path.join(lib_dir, "providers", "game_provider.dart"))
fix_riverpod(os.path.join(lib_dir, "providers", "profile_provider.dart"))

print("Fixes applied.")
