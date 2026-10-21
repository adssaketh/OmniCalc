package com.saketh.omnicalc;

import android.content.res.Configuration;
import android.os.Build;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "DynamicColor")
public class DynamicColorPlugin extends Plugin {
    private static final String[] PALETTES = {
        "system_accent1", "system_accent2", "system_accent3",
        "system_neutral1", "system_neutral2"
    };
    private static final String[] TONES = {
        "0", "10", "50", "100", "200", "300", "400", "500", "600", "700", "800", "900", "1000"
    };

    @PluginMethod
    public void getColors(PluginCall call) {
        JSObject ret = new JSObject();
        boolean supported = Build.VERSION.SDK_INT >= 31;
        ret.put("supported", supported);
        int night = getContext().getResources().getConfiguration().uiMode
                & Configuration.UI_MODE_NIGHT_MASK;
        ret.put("isDark", night == Configuration.UI_MODE_NIGHT_YES);
        if (supported) {
            JSObject colors = new JSObject();
            for (String palette : PALETTES) {
                for (String tone : TONES) {
                    int id = getContext().getResources()
                            .getIdentifier(palette + "_" + tone, "color", "android");
                    if (id != 0) {
                        int c = getContext().getColor(id);
                        colors.put(palette + "_" + tone, String.format("#%06X", 0xFFFFFF & c));
                    }
                }
            }
            ret.put("colors", colors);
        }
        call.resolve(ret);
    }
}
