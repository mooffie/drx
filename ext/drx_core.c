#include "ruby.h"
#include "st.h"

/**
 * Gets the Ruby's engine type of a variable.
 */
static VALUE t_get_type(VALUE self, VALUE obj)
{
  return INT2NUM(TYPE(obj));
}

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
  // @todo: Store something useful in the values?
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

// {{{ Locating methods

#include "node.h"

#define RSTR(s) rb_str_new2(s)

static t_do_locate_method(NODE *ND_method) {
  NODE *ND_scope = NULL, *ND_block = NULL;
  VALUE place;
  char line_s[20];
  
  //
  // The NODE_METHOD node
  //

  if (nd_type(ND_method) != NODE_METHOD/*0*/) {
    return RSTR("I'm expecting a NODE_METHOD here...");
  }
  
  //
  // The NODE_SCOPE node
  //
  
  ND_scope = ND_method->u2.node;

  if (nd_type(ND_scope) == NODE_CFUNC/*2*/) {
    return RSTR("That's a C function");
  }
  
  if (nd_type(ND_scope) == NODE_ATTRSET/*89*/) {
    return RSTR("That's an attr setter");
  }

  if (nd_type(ND_scope) == NODE_FBODY/*1*/) {
    return RSTR("That's an alias");
  }
  
  if (nd_type(ND_scope) == NODE_ZSUPER/*41*/) {
    // @todo The DateTime clas has a lot of these.
    return RSTR("That's a ZSUPER, whatver the heck it means!");
  }

  if (nd_type(ND_scope) != NODE_SCOPE/*3*/) {
    printf("I'm expecting a NODE_SCOPE HERE (got %d instead)\n", nd_type(ND_scope));
    return RSTR("I'm expecting a NODE_SCOPE HERE...");
  }
  
  //
  // The NODE_BLOCK node
  //
  
  ND_block = ND_scope->u3.node;

  if (nd_type(ND_block) != NODE_BLOCK/*4*/) {
    return RSTR("I'm expecting a NODE_BLOCK here...");
  }
  
  sprintf(line_s, "%d:", nd_line(ND_block));
  place = RSTR(line_s);
  rb_str_cat2(place, ND_block->nd_file);
  
  return place;
}

/*
 *  call-seq:
 *     Drx.locate_method(Date, "to_s")  => str
 *  
 *  Locates the filename and line-number where a method was defined. Returns a
 *  string of the form "89:/path/to/file.rb", or nil if method doens't exist.
 *  If the method exist but isn't a Ruby method (i.e., if it's written in C),
 *  the string returned will include an erorr message, e.g. "That's a C
 *  function".
 */
static VALUE t_locate_method(VALUE self, VALUE obj, VALUE method_name)
{
  const char *c_name;
  NODE *method_node;

  if (TYPE(obj) != T_CLASS && TYPE(obj) != T_ICLASS && TYPE(obj) != T_MODULE) {
    rb_raise(rb_eTypeError, "Only T_CLASS/T_MODULE is expected as the argument (got %d)", TYPE(obj));
  }
  if (!RCLASS(obj)->m_tbl) {
    return Qnil;
  }
  c_name = StringValuePtr(method_name);
  ID id = rb_intern(c_name);
  if (st_lookup(RCLASS(obj)->m_tbl, id, &method_node))  {
    return t_do_locate_method(method_node);
  } else {
    return Qnil;
  }
}

// }}}

VALUE mDrx;
VALUE mCore;

void Init_drx_core() {
  mDrx  = rb_define_module("Drx");
  mCore = rb_define_module_under(mDrx, "Core");
  rb_define_module_function(mCore, "get_iv_tbl", t_get_iv_tbl, 1);
  rb_define_module_function(mCore, "get_m_tbl", t_get_m_tbl, 1);
  rb_define_module_function(mCore, "get_super", t_get_super, 1);
  rb_define_module_function(mCore, "get_klass", t_get_klass, 1);
  rb_define_module_function(mCore, "get_flags", t_get_flags, 1);
  rb_define_module_function(mCore, "get_address", t_get_address, 1);
  rb_define_module_function(mCore, "get_type", t_get_type, 1);
  rb_define_module_function(mCore, "get_ivar", t_get_ivar, 2);
  rb_define_module_function(mCore, "locate_method", t_locate_method, 2);
  rb_define_const(mCore, "FL_SINGLETON", INT2FIX(FL_SINGLETON));
  rb_define_const(mCore, "T_OBJECT", INT2FIX(T_OBJECT));
  rb_define_const(mCore, "T_CLASS", INT2FIX(T_CLASS));
  rb_define_const(mCore, "T_ICLASS", INT2FIX(T_ICLASS));
  rb_define_const(mCore, "T_MODULE", INT2FIX(T_MODULE));
}
