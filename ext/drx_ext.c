#include "ruby.h"
#include "st.h"

// Helper for t_get_iv_tbl().
int record_var(st_data_t key, st_data_t value, VALUE hash) {
  // I originally did the following, but it breaks for object::Tk*. Perhaps these
  // values are T_NODEs? (e.g. aliases) @todo: debug using INT2FIX(TYPE(value)).
  rb_hash_aset(hash, ID2SYM(key), value);
  // So...
  rb_hash_aset(hash, ID2SYM(key), Qtrue);
  return ST_CONTINUE;
}

/**
 * Gets the iv_tbl of the object, as a Ruby hash.
 */
static VALUE t_get_iv_tbl(VALUE self, VALUE obj)
{
  VALUE hash;
  hash = rb_hash_new();

  if (TYPE(obj) != T_OBJECT && TYPE(obj) != T_CLASS && TYPE(obj) != T_ICLASS && TYPE(obj) != T_MODULE) {
    rb_raise(rb_eTypeError, "Only T_OBJECT/T_CLASS/T_MODULE is expected as the argument (got %d)", TYPE(obj));
  }
  
  if (ROBJECT(obj)->iv_tbl) {
    st_foreach(ROBJECT(obj)->iv_tbl, record_var, (st_data_t)hash);
  }

  return hash;
}

/**
 * Extracts one varibale from an object iv_tbl.
 */
static VALUE t_get_ivar(VALUE self, VALUE obj, VALUE var_name)
{
  const char *c_name;
  if (TYPE(obj) != T_OBJECT && TYPE(obj) != T_CLASS && TYPE(obj) != T_ICLASS && TYPE(obj) != T_MODULE) {
    rb_raise(rb_eTypeError, "Only T_OBJECT/T_CLASS/T_MODULE is expected as the argument (got %d)", TYPE(obj));
  }
  c_name = StringValuePtr(var_name);
  return rb_iv_get(obj, c_name);
}

/**
 * Returns a class's super.
 *
 * In contrast to Class#superclass, this function doesn't skip singletons and T_ICLASS.
 */
static VALUE t_get_super(VALUE self, VALUE obj)
{
  VALUE super;
  if (TYPE(obj) != T_CLASS && TYPE(obj) != T_ICLASS && TYPE(obj) != T_MODULE) {
    rb_raise(rb_eTypeError, "Only T_CLASS/T_MODULE is expected as the argument (got %d)", TYPE(obj));
  }
  return RCLASS(obj)->super ? RCLASS(obj)->super : Qnil;
}

/**
 * Returns an object's klass.
 *
 * In contrast to Object#class, this function doesn't skip singletons and T_ICLASS.
 */
static VALUE t_get_klass(VALUE self, VALUE obj)
{
  return CLASS_OF(obj);
  // Note: we can't simply do 'RBASIC(obj)->klass', because obj may be an 'immediate'.
}

/**
 * Returns an object's flags.
 */
static VALUE t_get_flags(VALUE self, VALUE obj)
{
  return INT2NUM(RBASIC(obj)->flags);
}

// Helper for t_get_m_tbl().
int record_method(st_data_t key, st_data_t value, VALUE hash) {
  // @todo: Store something useful in the values.
  rb_hash_aset(hash, key == ID_ALLOCATOR ? rb_str_new2("<Allocator>") : ID2SYM(key), INT2FIX(666));
  return ST_CONTINUE;
}

/**
 * Gets the m_tbl of a class.
 */
static VALUE t_get_m_tbl(VALUE self, VALUE obj)
{
  VALUE hash;

  if (TYPE(obj) != T_CLASS && TYPE(obj) != T_ICLASS && TYPE(obj) != T_MODULE) {
    rb_raise(rb_eTypeError, "Only T_CLASS/T_MODULE is expected as the argument (got %d)", TYPE(obj));
  }

  hash = rb_hash_new();
  st_foreach(RCLASS(obj)->m_tbl, record_method, (st_data_t)hash);
  return hash;
}

/**
 * Returns the object's "id".
 *
 * This is an alternative to Object#__id__ because the latter doesn't
 * work for T_ICLASS.
 */
static VALUE t_get_address(VALUE self, VALUE obj)
{
  return INT2NUM(obj);
}

/**
 * Gets the Ruby's engine type of a variable.
 */
static VALUE t_get_type(VALUE self, VALUE obj)
{
  return INT2NUM(TYPE(obj));
}

VALUE mDrx;

void Init_drx_ext() {
  mDrx = rb_define_module("Drx");
  rb_define_module_function(mDrx, "get_iv_tbl", t_get_iv_tbl, 1);
  rb_define_module_function(mDrx, "get_m_tbl", t_get_m_tbl, 1);
  rb_define_module_function(mDrx, "get_super", t_get_super, 1);
  rb_define_module_function(mDrx, "get_klass", t_get_klass, 1);
  rb_define_module_function(mDrx, "get_flags", t_get_flags, 1);
  rb_define_module_function(mDrx, "get_address", t_get_address, 1);
  rb_define_module_function(mDrx, "get_type", t_get_type, 1);
  rb_define_module_function(mDrx, "get_ivar", t_get_ivar, 2);
  rb_define_const(mDrx, "FL_SINGLETON", INT2FIX(FL_SINGLETON));
  rb_define_const(mDrx, "T_OBJECT", INT2FIX(T_OBJECT));
  rb_define_const(mDrx, "T_CLASS", INT2FIX(T_CLASS));
  rb_define_const(mDrx, "T_ICLASS", INT2FIX(T_ICLASS));
  rb_define_const(mDrx, "T_MODULE", INT2FIX(T_MODULE));
}
