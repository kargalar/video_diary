import os
import re

# Script'in bulunduğu dizini al
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def fix_with_opacity():
    """Replace withOpacity with withValues"""
    dart_files = []
    lib_path = os.path.join(SCRIPT_DIR, 'lib')
    for root, dirs, files in os.walk(lib_path):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))

    updated_count = 0
    for file_path in dart_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace withOpacity with withValues
            original_content = content
            content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
            
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f'✓ Updated: {file_path}')
                updated_count += 1
        except Exception as e:
            print(f'✗ Error in {file_path}: {e}')

    print(f'\nTotal files updated: {updated_count}')


def replace_print_with_debug_print():
    """Replace print() with debugPrint()"""
    dart_files = []
    lib_path = os.path.join(SCRIPT_DIR, 'lib')
    for root, dirs, files in os.walk(lib_path):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))

    updated_count = 0
    for file_path in dart_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # Replace print( with debugPrint(
            # Make sure it's not already debugPrint
            content = re.sub(r'(?<!debug)print\(', 'debugPrint(', content)
            
            # Add import if we made changes and it's not already imported
            if content != original_content:
                if "import 'package:flutter/foundation.dart';" not in content:
                    # Add import after other imports
                    if content.startswith('import'):
                        # Find the last import statement
                        imports_end = 0
                        for match in re.finditer(r'^import\s.*?;$', content, re.MULTILINE):
                            imports_end = match.end()
                        if imports_end > 0:
                            content = content[:imports_end] + "\nimport 'package:flutter/foundation.dart';" + content[imports_end:]
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f'✓ Updated: {file_path}')
                updated_count += 1
        except Exception as e:
            print(f'✗ Error in {file_path}: {e}')

    print(f'\nTotal files updated: {updated_count}')


if __name__ == '__main__':
    print('🔧 Starting Dart file fixes...\n')
    
    print('=' * 50)
    print('1. Fixing withOpacity -> withValues...')
    print('=' * 50)
    fix_with_opacity()
    
    print('\n' + '=' * 50)
    print('2. Fixing print() -> debugPrint()...')
    print('=' * 50)
    replace_print_with_debug_print()
    
    print('\n✅ All fixes completed!')
