# Split Flap Display

פרויקט Flutter שמיישם תצוגת טקסט באנימציה בהשראת לוחות `split-flap` מכניים: כל אות מוצגת על גבי אריח, והאריח מסתובב בציר האופקי כאשר ההודעה משתנה.

הדוגמה הראשונית מחליפה בין כמה הודעות באופן אוטומטי ומדגימה בסיס לאפליקציה שתוכל בהמשך להתחבר לקלט משתמש, לשעון, ל־API או לחומרה אמיתית.

## השראה

הרעיון החזותי וההתייחסות למבנה המכני מבוססים על הפרויקט [Split Flap Display 3D Printed Modular Compact Enclosure](https://www.instructables.com/Split-Flap-Display-3D-Printed-Modular-Compact-Encl/).

## הרצה

נדרש Flutter SDK מותקן:

```bash
flutter pub get
flutter run
```

בדיקות:

```bash
flutter test
```

## מבנה

- `lib/main.dart` מכיל את האפליקציה, רכיב `SplitFlapText` ואריח אנימציה יחיד.
- `test/widget_test.dart` בודק שהאפליקציה נטענת ושהאריחים מוצגים.

הקישור שסופק למאגר המקור `flutter_lib_skelaton` אינו נגיש ומחזיר 404, ולכן לא היה קוד מקור שניתן להעתיק ממנו. הפרויקט הנוכחי הוא בסיס Flutter עצמאי שנבנה עבור Split Flap Display.