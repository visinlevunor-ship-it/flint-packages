    // Flint Linux: a gray flint stone striking gold sparks (added by Flint's fastfetch port)
    #ifdef FASTFETCH_DATATEXT_LOGO_FLINT
    {
        .names = { "Flint", "Flint Linux" },
        .lines = FASTFETCH_DATATEXT_LOGO_FLINT,
        .colors = {
            "38;2;214;220;230", // light facets
            "38;2;130;140;156", // shaded facets
            "38;2;255;201;74",  // sparks
        },
        .colorKeys = "38;2;255;201;74",
        .colorTitle = "38;2;214;220;230",
    },
    #endif
    #ifdef FASTFETCH_DATATEXT_LOGO_FLINT_SMALL
    {
        .names = { "Flint_small" },
        .type = FF_LOGO_LINE_TYPE_SMALL_BIT,
        .lines = FASTFETCH_DATATEXT_LOGO_FLINT_SMALL,
        .colors = {
            "38;2;238;241;245", // the six facet greys of the logo, lightest first
            "38;2;223;228;235",
            "38;2;195;204;216",
            "38;2;174;184;198",
            "38;2;154;165;181",
            "38;2;127;138;155",
            "38;2;255;201;74",  // sparks
        },
        .colorKeys = "38;2;255;201;74",
        .colorTitle = "38;2;214;220;230",
    },
    #endif
