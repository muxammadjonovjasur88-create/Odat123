import json
import pathlib
files = [
    pathlib.Path('assets/translations/en.json'),
    pathlib.Path('assets/translations/ru.json'),
    pathlib.Path('assets/translations/uz.json'),
]
for path in files:
    with path.open(encoding='utf-8') as f:
        json.load(f)
    print(f'{path}: OK')
