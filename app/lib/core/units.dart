/// Birlik o'tkazish. Backend'dagi app/units.py bilan bir xil qoida:
/// faqat donaM2 belgilangan toshlar uchun 1 dona = 0,25 m². Boshqalarga tatbiq etilmaydi.
/// Yakuniy hisob-kitobni baribir backend (Decimal) bajaradi.
class Units {
  static const double stoneDonaM2 = 0.25;

  static double donaToBase(double dona, double? donaM2) {
    if (donaM2 == null || donaM2 <= 0) {
      throw ArgumentError('Bu mahsulot dona bilan sotilmaydi');
    }
    return dona * donaM2;
  }
}
