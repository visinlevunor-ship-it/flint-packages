/* dwm-1: Flint's dwm. Super is the modifier key; Super+/ shows every key.
 * Change it and rebuild with ports/dwm/build.sh OUTDIR flint (flint-packages). */

/* appearance */
static const unsigned int borderpx  = 2;        /* window border */
static const unsigned int gappx     = 10;       /* gaps between windows (Super+minus/equal) */
static const unsigned int snap      = 32;       /* snap distance for floating windows */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
static const int barpad             = 12;       /* extra bar height, in pixels */
static const char *fonts[]          = { "JetBrains Mono:size=10:style=Medium", "monospace:size=10" };
static const char dmenufont[]       = "JetBrains Mono:size=11";

/* Flint's colors: the logo's grays on near-black, gold for what is in focus */
static const char col_black[]       = "#0b0b0c";
static const char col_dark[]        = "#1b1c1f";
static const char col_line[]        = "#3a3d44";
static const char col_gray[]        = "#c3ccd8";
static const char col_white[]       = "#eef1f5";
static const char col_gold[]        = "#ffc94a";
static const char *colors[][3]      = {
	/*                fg          bg          border   */
	[SchemeNorm]  = { col_gray,   col_black,  col_line },
	[SchemeSel]   = { col_gold,   col_dark,   col_gold },
	[SchemeTitle] = { col_white,  col_black,  col_line },
};

/* tagging: only tags with windows are shown in the bar */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* class            instance    title       tags mask     isfloating   monitor */
	{ "firefox",        NULL,       NULL,       1 << 1,       0,           -1 },
	{ NULL,             NULL,       "Picture-in-Picture", 0,  1,           -1 },
	{ "Pavucontrol",    NULL,       NULL,       0,            1,           -1 },
	{ "flint-float",    NULL,       NULL,       0,            1,           -1 },
};

/* layout(s) */
static const float mfact     = 0.55; /* size of the master area [0.05..0.95] */
static const int nmaster     = 1;    /* number of windows in the master area */
static const int resizehints = 0;    /* 0: terminals fill their tile exactly, gaps stay even */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */
static const int refreshrate = 120;  /* refresh rate (per second) for client move/resize */

static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },    /* first entry is default */
	{ "[M]",      monocle },
	{ "><>",      NULL },    /* no layout function means floating behavior */
};

/* key definitions */
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont, "-nb", col_black, "-nf", col_gray, "-sb", col_gold, "-sf", col_black, "-p", "run", NULL };
static const char *termcmd[]  = { "st", NULL };
static const char *floatterm[] = { "st", "-c", "flint-float", "-g", "100x30", NULL };
static const char *browsercmd[] = { "flint-browser", NULL };
static const char *keyscmd[]  = { "flint-dwm-keys", NULL };

static const Key keys[] = {
	/* modifier                     key           function        argument */
	{ MODKEY,                       XK_Return,    spawn,          {.v = termcmd } },
	{ MODKEY|ShiftMask,             XK_Return,    spawn,          {.v = floatterm } },
	{ MODKEY,                       XK_d,         spawn,          {.v = dmenucmd } },
	{ MODKEY,                       XK_w,         spawn,          {.v = browsercmd } },
	{ MODKEY,                       XK_slash,     spawn,          {.v = keyscmd } },
	{ MODKEY,                       XK_q,         killclient,     {0} },
	{ MODKEY|ShiftMask,             XK_e,         quit,           {0} },

	/* focus and move windows: vim keys or arrows */
	{ MODKEY,                       XK_j,         focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_k,         focusstack,     {.i = -1 } },
	{ MODKEY,                       XK_Down,      focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_Up,        focusstack,     {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_j,         movestack,      {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_k,         movestack,      {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_Down,      movestack,      {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_Up,        movestack,      {.i = -1 } },
	{ MODKEY,                       XK_h,         setmfact,       {.f = -0.05} },
	{ MODKEY,                       XK_l,         setmfact,       {.f = +0.05} },
	{ MODKEY,                       XK_Left,      setmfact,       {.f = -0.05} },
	{ MODKEY,                       XK_Right,     setmfact,       {.f = +0.05} },
	{ MODKEY,                       XK_space,     zoom,           {0} },
	{ MODKEY,                       XK_i,         incnmaster,     {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_i,         incnmaster,     {.i = -1 } },

	/* layouts */
	{ MODKEY,                       XK_t,         setlayout,      {.v = &layouts[0]} },
	{ MODKEY,                       XK_m,         setlayout,      {.v = &layouts[1]} },
	{ MODKEY|ShiftMask,             XK_f,         setlayout,      {.v = &layouts[2]} },
	{ MODKEY,                       XK_f,         togglefullscr,  {0} },
	{ MODKEY|ShiftMask,             XK_space,     togglefloating, {0} },
	{ MODKEY,                       XK_b,         togglebar,      {0} },
	{ MODKEY,                       XK_minus,     setgaps,        {.i = -2 } },
	{ MODKEY,                       XK_equal,     setgaps,        {.i = +2 } },
	{ MODKEY|ShiftMask,             XK_equal,     setgaps,        {.i = 0  } },

	/* tags (workspaces) */
	{ MODKEY,                       XK_Tab,       view,           {0} },
	{ MODKEY,                       XK_0,         view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,         tag,            {.ui = ~0 } },
	{ MODKEY,                       XK_comma,     focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_period,    focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,     tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_period,    tagmon,         {.i = +1 } },
	TAGKEYS(                        XK_1,                         0)
	TAGKEYS(                        XK_2,                         1)
	TAGKEYS(                        XK_3,                         2)
	TAGKEYS(                        XK_4,                         3)
	TAGKEYS(                        XK_5,                         4)
	TAGKEYS(                        XK_6,                         5)
	TAGKEYS(                        XK_7,                         6)
	TAGKEYS(                        XK_8,                         7)
	TAGKEYS(                        XK_9,                         8)
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
	{ ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[1]} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button1,        spawn,          {.v = keyscmd } },
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};
