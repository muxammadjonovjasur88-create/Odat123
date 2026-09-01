const fs = require('fs');

function removeConst(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');
  content = content.replace(/const\s+Text\(/g, 'Text(');
  content = content.replace(/const\s+Expanded\(/g, 'Expanded(');
  content = content.replace(/const\s+Column\(/g, 'Column(');
  content = content.replace(/const\s+Row\(/g, 'Row(');
  content = content.replace(/const\s+Center\(/g, 'Center(');
  content = content.replace(/const\s+Padding\(/g, 'Padding(');
  content = content.replace(/const\s+SizedBox\(/g, 'SizedBox(');
  // Also 'children: const ['
  content = content.replace(/children:\s*const\s*\[/g, 'children: [');
  fs.writeFileSync(filePath, content, 'utf8');
}

removeConst('D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_home_screen.dart');
removeConst('D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_location_screen.dart');
removeConst('D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_wallet_screen.dart');

console.log('Consts removed aggressively.');
