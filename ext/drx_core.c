#include "ruby.h"

#ifndef RUBY_VM
# define RUBY_1_8
#endif

#ifdef RUBY_1_8
# include "st.h"
#else
# include "ruby/st.h"
#endif

/**
 * Gets the Ruby's engine type of a variable.
 */
static VALUE t_get_type(VALUE self, VALUE obj)
{
  return INT2NUM(TYPE(obj));
}

// Helper for t_get_iv_tbl().
static int record_var(st_data_t key, st_data_t value, VALUE hash) {
  // We don't put the 'value' in the hash because it may not be a Ruby
  // conventional value but a NODE (and acidentally printing it may crash ruby).
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

#ifdef RUBY_1_8
  if (ROBJECT(obj)->iv_tbl) {
    st_foreach(ROBJECT(obj)->iv_tbl, record_var, (st_data_t)hash);
  }
#else
  rb_ivar_foreach(obj, record_var, hash);
#endif

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
  if (TYPE(obj) != T_CLASS && TYPE(obj) != T_ICLASS && TYPE(obj) != T_MODULE) {
    rb_raise(rb_eTypeError, "Only T_CLASS/T_MODULE is expected as the argument (got %d)", TYPE(obj));
  }
  return RCLASS_SUPER(obj) ? RCLASS_SUPER(obj) : Qnil;
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
// @todo: Store something useful in the values?
static int record_method(st_data_t key, st_data_t value, VALUE hash) {
  static ID id_allocator_symb = 0;
  if (!id_allocator_symb) {
    id_allocator_symb = rb_intern("<Allocator>");
  }
  rb_hash_aset(hash, ID2SYM(key == ID_ALLOCATOR ? id_allocator_symb : key), Qtrue);
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

#ifdef RUBY_1_8
// {{{ Locating methods

#include "node.h"

#define RSTR(s) rb_str_new2(s)

static VALUE t_do_locate_method(NODE *ND_method) {
  NODE *ND_scope = NULL, *ND_block = NULL;
  VALUE location;
  char line_s[20];

  //
  // The NODE_METHOD node
  //

  if (nd_type(ND_method) != NODE_METHOD/*0*/) {
    return RSTR("<I'm expecting a NODE_METHOD here...>");
  }

  //
  // The NODE_SCOPE node
  //

  ND_scope = ND_method->u2.node;
  if (!ND_scope) {
     // When we use undef() to undefine a method.
     return RSTR("<undef>");
  }

  if (nd_type(ND_scope) == NODE_FBODY/*1*/) {
    return RSTR("<alias>");
  }

  if (nd_type(ND_scope) == NODE_CFUNC/*2*/) {
    return RSTR("<c>");
  }

  if (nd_type(ND_scope) == NODE_IVAR/*50*/) {
    return RSTR("<attr reader>");
  }

  if (nd_type(ND_scope) == NODE_ATTRSET/*89*/) {
    return RSTR("<attr setter>");
  }

  if (nd_type(ND_scope) == NODE_ZSUPER/*41*/) {
    // When we change visibility (using 'private :method' or 'public :method') of
    // a base method, this node is created.
    return RSTR("<zsuper>");
  }

  if (nd_type(ND_scope) == NODE_BMETHOD/*99*/) {
    // This is created by define_method().
    VALUE proc;
    proc = (VALUE)ND_scope->u3.node;
    // proc_to_s(), in eval.c, shows how to extract the location. However,
    // for this we need access to the BLOCK structure. Unfortunately,
    // that BLOCK is defined in eval.c, not in any .h file we can #include.
    // So instead we resort to a dirty trick: we parse the output of Proc#to_s.
    return rb_funcall(proc, rb_intern("_location"), 0, 0);
  }

  if (nd_type(ND_scope) != NODE_SCOPE/*3*/) {
    printf("I'm expecting a NODE_SCOPE HERE (got %d instead)\n", nd_type(ND_scope));
    return RSTR("<I'm expecting a NODE_SCOPE HERE...>");
  }

  //
  // The NODE_BLOCK node
  //

  ND_block = ND_scope->u3.node;

  if (!ND_block || nd_type(ND_block) != NODE_BLOCK/*4*/) {
    return RSTR("<I'm expecting a NODE_BLOCK here...>");
  }

  location = rb_ary_new();
  rb_ary_push(location, RSTR(ND_block->nd_file));
  rb_ary_push(location, INT2FIX(nd_line(ND_block)));

  return location;
}

/*
 *  call-seq:
 *     Drx::Core::locate_method(Date, "to_s")  => ...
 *
 *  Locates the filename and line-number where a method was defined.
 *
 *  Returns one of:
 *   - [ "/path/to/file.rb", 89 ]
 *   - A string of the form "<identifier>" if the method isn't written
 *     in Ruby. Possibilities are <c>, <alias>, <attr reader>, and more.
 *   - raises NameError if the method doesn't exist.
 */
static VALUE t_locate_method(VALUE self, VALUE obj, VALUE method_name)
{
  const char *c_name;
  NODE *method_node;

  if (TYPE(obj) != T_CLASS && TYPE(obj) != T_ICLASS && TYPE(obj) != T_MODULE) {
    rb_raise(rb_eTypeError, "Only T_CLASS/T_MODULE is expected as the argument (got %d)", TYPE(obj));
  }
  c_name = StringValuePtr(method_name);
  ID id = rb_intern(c_name);
  if (RCLASS(obj)->m_tbl && st_lookup(RCLASS(obj)->m_tbl, id, (st_data_t *)&method_node))  {
    return t_do_locate_method(method_node);
  } else {
    rb_raise(rb_eNameError, "method not found");
  }
}

// }}}
#endif // RUBY_1_8

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
#ifdef RUBY_1_8
  rb_define_module_function(mCore, "locate_method", t_locate_method, 2);
  // For the following, see explanation in t_do_locate_method().
  rb_eval_string("\
    class ::Proc;\
      def _location;\
        if to_s =~ /@(.*?):(\\d+)>$/ then [$1, $2.to_i] end;\
      end;\
    end");
#endif
  rb_define_const(mCore, "FL_SINGLETON", INT2FIX(FL_SINGLETON));
  rb_define_const(mCore, "T_OBJECT", INT2FIX(T_OBJECT));
  rb_define_const(mCore, "T_CLASS", INT2FIX(T_CLASS));
  rb_define_const(mCore, "T_ICLASS", INT2FIX(T_ICLASS));
  rb_define_const(mCore, "T_MODULE", INT2FIX(T_MODULE));
}
