// required for the web server impl
#include <unistd.h>
#include <lua.h>
#include <lauxlib.h>

#define LST lua_State* L
#define EXEC_WORDS 64

int l_fork(LST) {
  pid_t result = fork();
  lua_pushinteger(L, result);
  return 1;
}

int l_execvp(LST) {
  const char* argv[EXEC_WORDS];
  int args = lua_gettop(L);
  if (args > EXEC_WORDS) {
    lua_pushliteral(L, "too many arguments to l_execvp");
    lua_error(L);
  }
  const char* path = luaL_checkstring(L, 1);
  argv[0] = path;
  if (args > 1) {
    for (int i = 0; i < args; i++) {
      argv[i] = luaL_checkstring(L, i + 2);
      argv[i+1] = NULL;
    }
  } else {
    argv[1] = NULL;
  }
  execvp(path, argv);
}

static luaL_Reg const lib[] = {
  { "fork", l_fork },
  { "execvp", l_execvp },
  { NULL, NULL }
};

int luaopen_fork(LST) {
  luaL_newlib(L, lib);
  return 1;
}
