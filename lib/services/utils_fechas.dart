import 'package:intl/intl.dart';

class UtilsFechas {
  static final DateFormat _fmtFecha = DateFormat('yyyy-MM-dd');
  static final DateFormat _fmtFechaHora = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _fmtHumana = DateFormat('dd/MM/yyyy');

  static String fechaClase(DateTime dt) => _fmtFecha.format(dt);
  static String fechaHora(DateTime dt) => _fmtFechaHora.format(dt);
  static String fechaHumana(DateTime dt) => _fmtHumana.format(dt);
}