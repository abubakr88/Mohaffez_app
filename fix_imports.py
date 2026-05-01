#!/usr/bin/env python3
"""
Script to fix imports after Melos monorepo migration.
Run this from the project root.
"""

import os
import re

# Mapping of old import patterns to new ones
REPLACEMENTS = [
    # Models
    (r"import ['\"]\.\./models/", "import 'package:mohaffez_core/src/models/"),
    (r"import ['\"]\.\./\.\./models/", "import 'package:mohaffez_core/src/models/"),
    (r"import ['\"]\.\./\.\./\.\./models/", "import 'package:mohaffez_core/src/models/"),

    # Repositories
    (r"import ['\"]\.\./repositories/", "import 'package:mohaffez_core/src/repositories/"),
    (r"import ['\"]\.\./\.\./repositories/", "import 'package:mohaffez_core/src/repositories/"),
    (r"import ['\"]\.\./\.\./\.\./repositories/", "import 'package:mohaffez_core/src/repositories/"),

    # Providers (these were moved to core)
    (r"import ['\"]\.\./providers/(admin_provider|auth_provider|booking_flow_provider|booking_provider|challenge_questions_provider|mohaffez_provider|notification_provider_paginated|payment_provider|pricing_provider|promo_code_provider|session_provider_paginated|student_rewards_provider|subscription_provider|suspension_provider|system_config_provider|teacher_setup_provider|user_provider)\.dart['\"]",
     r"import 'package:mohaffez_core/src/providers/\1.dart'"),
    (r"import ['\"]\.\./\.\./providers/(admin_provider|auth_provider|booking_flow_provider|booking_provider|challenge_questions_provider|mohaffez_provider|notification_provider_paginated|payment_provider|pricing_provider|promo_code_provider|session_provider_paginated|student_rewards_provider|subscription_provider|suspension_provider|system_config_provider|teacher_setup_provider|user_provider)\.dart['\"]",
     r"import 'package:mohaffez_core/src/providers/\1.dart'"),

    # Services (platform-agnostic ones moved to core)
    (r"import ['\"]\.\./services/(cache_service|connectivity_service|direct_payment_service|follow_service|prayer_time_service|pricing_service|quran_service)\.dart['\"]",
     r"import 'package:mohaffez_core/src/services/\1.dart'"),
    (r"import ['\"]\.\./\.\./services/(cache_service|connectivity_service|direct_payment_service|follow_service|prayer_time_service|pricing_service|quran_service)\.dart['\"]",
     r"import 'package:mohaffez_core/src/services/\1.dart'"),

    # Constants
    (r"import ['\"]\.\./shared/constants/", "import 'package:mohaffez_core/src/constants/"),
    (r"import ['\"]\.\./\.\./shared/constants/", "import 'package:mohaffez_core/src/constants/"),
    (r"import ['\"]\.\./\.\./\.\./shared/constants/", "import 'package:mohaffez_core/src/constants/"),

    # Utils
    (r"import ['\"]\.\./shared/utils/", "import 'package:mohaffez_core/src/utils/"),
    (r"import ['\"]\.\./\.\./shared/utils/", "import 'package:mohaffez_core/src/utils/"),
    (r"import ['\"]\.\./\.\./\.\./shared/utils/", "import 'package:mohaffez_core/src/utils/"),

    # Theme
    (r"import ['\"]\.\./shared/theme/app_theme_constants\.dart['\"]", "import 'package:mohaffez_core/src/theme/app_theme_constants.dart'"),
    (r"import ['\"]\.\./\.\./shared/theme/app_theme_constants\.dart['\"]", "import 'package:mohaffez_core/src/theme/app_theme_constants.dart'"),
    (r"import ['\"]\.\./\.\./\.\./shared/theme/app_theme_constants\.dart['\"]", "import 'package:mohaffez_core/src/theme/app_theme_constants.dart'"),
]

def fix_imports_in_file(filepath):
    """Fix imports in a single Dart file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        original = content
        for pattern, replacement in REPLACEMENTS:
            content = re.sub(pattern, replacement, content)

        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Fixed: {filepath}")
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    base_dir = "packages/mohaffez_mobile/lib"
    fixed_count = 0

    for root, dirs, files in os.walk(base_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                if fix_imports_in_file(filepath):
                    fixed_count += 1

    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()
