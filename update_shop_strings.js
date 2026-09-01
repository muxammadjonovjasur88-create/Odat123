const fs = require('fs');

const file1 = 'd:\\odat123\\Flowa\\lib\\features\\shop\\presentation\\screens\\my_purchases_screen.dart';
if (fs.existsSync(file1)) {
  let content1 = fs.readFileSync(file1, 'utf8');

  content1 = content1.replaceAll("'Mening xaridlarim'", "'shop.my_purchases'.tr()");
  content1 = content1.replaceAll("'Kuponlarim'", "'shop.my_coupons'.tr()");
  content1 = content1.replaceAll("'Xaridlar tarixi'", "'shop.purchase_history'.tr()");
  content1 = content1.replaceAll("'Hali hech qanday kuponingiz yo\\'q.'", "'shop.no_coupons_yet'.tr()");
  content1 = content1.replaceAll("'Do\\'kondan sovg\\'alar yoki chegirmalar xarid qiling.'", "'shop.buy_gifts_from_shop'.tr()");
  content1 = content1.replaceAll("'Do\\'konga o\\'tish'", "'shop.go_to_shop'.tr()");
  content1 = content1.replaceAll("'Xaridlar tarixi bo\\'sh.'", "'shop.purchase_history_empty'.tr()");

  fs.writeFileSync(file1, content1, 'utf8');
  console.log('Done my_purchases_screen');
} else {
  console.log('Not found');
}
