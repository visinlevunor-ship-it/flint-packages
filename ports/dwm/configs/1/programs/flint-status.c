/* flint-status: the text on the right of dwm's bar.
 *
 * Every two seconds it puts battery, network, CPU, memory and the time into the root
 * window's name, which is where dwm reads its status from. Everything comes from /proc and
 * /sys, so it needs no other program. Sections that do not apply (no battery on a desktop)
 * are left out. */
#include <X11/Xlib.h>
#include <dirent.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define SEP "  |  "

static unsigned long long prev_idle, prev_total;

static int read_line(const char *path, char *buf, size_t n)
{
	FILE *f = fopen(path, "r");
	if (!f)
		return 0;
	int ok = fgets(buf, (int)n, f) != NULL;
	fclose(f);
	if (ok)
		buf[strcspn(buf, "\n")] = 0;
	return ok;
}

static void add(char *out, size_t n, const char *part)
{
	if (!*part)
		return;
	if (*out)
		strncat(out, SEP, n - strlen(out) - 1);
	strncat(out, part, n - strlen(out) - 1);
}

static void battery(char *buf, size_t n)
{
	DIR *d = opendir("/sys/class/power_supply");
	struct dirent *e;
	char path[300], type[32], cap[16], status[32];

	*buf = 0;
	if (!d)
		return;
	while ((e = readdir(d))) {
		if (e->d_name[0] == '.')
			continue;
		snprintf(path, sizeof path, "/sys/class/power_supply/%s/type", e->d_name);
		if (!read_line(path, type, sizeof type) || strcmp(type, "Battery"))
			continue;
		snprintf(path, sizeof path, "/sys/class/power_supply/%s/capacity", e->d_name);
		if (!read_line(path, cap, sizeof cap))
			continue;
		snprintf(path, sizeof path, "/sys/class/power_supply/%s/status", e->d_name);
		if (!read_line(path, status, sizeof status))
			*status = 0;
		snprintf(buf, n, "BAT %s%%%s", cap,
		         !strcmp(status, "Charging") ? " +" : !strcmp(status, "Full") ? " =" : "");
		break;
	}
	closedir(d);
}

static void network(char *buf, size_t n)
{
	/* wifi: the interface and link quality (out of 70) from /proc/net/wireless */
	FILE *f = fopen("/proc/net/wireless", "r");
	char line[256], ifname[32];
	float q;

	*buf = 0;
	if (f) {
		while (fgets(line, sizeof line, f))
			if (sscanf(line, " %31[^:]: %*s %f", ifname, &q) == 2) {
				snprintf(buf, n, "WIFI %d%%", (int)(q * 100 / 70 > 100 ? 100 : q * 100 / 70));
				break;
			}
		fclose(f);
	}
	if (*buf)
		return;
	/* otherwise any wired interface that is up */
	DIR *d = opendir("/sys/class/net");
	struct dirent *e;
	char path[300], state[16];
	if (!d)
		return;
	while ((e = readdir(d))) {
		if (e->d_name[0] == '.' || !strcmp(e->d_name, "lo"))
			continue;
		snprintf(path, sizeof path, "/sys/class/net/%s/operstate", e->d_name);
		if (read_line(path, state, sizeof state) && !strcmp(state, "up")) {
			snprintf(buf, n, "NET %s", e->d_name);
			break;
		}
	}
	closedir(d);
	if (!*buf)
		snprintf(buf, n, "NET down");
}

static void cpu(char *buf, size_t n)
{
	unsigned long long v[8] = {0}, idle, total = 0;
	char line[256];

	*buf = 0;
	if (!read_line("/proc/stat", line, sizeof line))
		return;
	if (sscanf(line, "cpu %llu %llu %llu %llu %llu %llu %llu %llu",
	           &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6], &v[7]) < 4)
		return;
	for (int i = 0; i < 8; i++)
		total += v[i];
	idle = v[3] + v[4];
	if (prev_total && total > prev_total)
		snprintf(buf, n, "CPU %2llu%%",
		         100 - (idle - prev_idle) * 100 / (total - prev_total));
	else
		snprintf(buf, n, "CPU  0%%");
	prev_idle = idle;
	prev_total = total;
}

static void memory(char *buf, size_t n)
{
	FILE *f = fopen("/proc/meminfo", "r");
	char line[128];
	unsigned long long total = 0, avail = 0, kb;

	*buf = 0;
	if (!f)
		return;
	while (fgets(line, sizeof line, f)) {
		if (sscanf(line, "MemTotal: %llu kB", &kb) == 1)
			total = kb;
		else if (sscanf(line, "MemAvailable: %llu kB", &kb) == 1)
			avail = kb;
	}
	fclose(f);
	if (total) {
		unsigned long long used = (total - avail) / 1024;
		if (used >= 1024)
			snprintf(buf, n, "MEM %.1fG", used / 1024.0);
		else
			snprintf(buf, n, "MEM %lluM", used);
	}
}

int main(void)
{
	Display *dpy = XOpenDisplay(NULL);
	char status[512], part[128];

	if (!dpy) {
		fprintf(stderr, "flint-status: cannot open the X display\n");
		return 1;
	}
	signal(SIGCHLD, SIG_IGN);
	for (;;) {
		*status = 0;
		battery(part, sizeof part), add(status, sizeof status, part);
		network(part, sizeof part), add(status, sizeof status, part);
		cpu(part, sizeof part), add(status, sizeof status, part);
		memory(part, sizeof part), add(status, sizeof status, part);
		time_t t = time(NULL);
		strftime(part, sizeof part, "%a %d %b  %H:%M", localtime(&t));
		add(status, sizeof status, part);
		strncat(status, " ", sizeof status - strlen(status) - 1);
		XStoreName(dpy, DefaultRootWindow(dpy), status);
		if (XFlush(dpy) < 0 || XConnectionNumber(dpy) < 0)
			break;
		sleep(2);
		/* quit with the X server */
		if (XPending(dpy) < 0)
			break;
	}
	XCloseDisplay(dpy);
	return 0;
}
