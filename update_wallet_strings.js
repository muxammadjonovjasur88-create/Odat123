const fs = require('fs');

const file1 = 'D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_wallet_screen.dart';
let content1 = fs.readFileSync(file1, 'utf8');

content1 = content1.replaceAll("'Hamyon ma\\'lumoti yo\\'q'", "'family.no_wallet_data'.tr()");
content1 = content1.replaceAll("'Hamyon ma\\'lumotlarini yuklashda xatolik'", "'family.wallet_load_error'.tr()");

fs.writeFileSync(file1, content1, 'utf8');
console.log('Done wallet screen');
