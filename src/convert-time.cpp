#include "convert-time.h"

#include <climits>

int convert_time_to_seconds(std::string hms) {
    // trim surrounding whitespace; malformed strings return NA_INTEGER
    const char* ws = " \t\r\n";
    const size_t b = hms.find_first_not_of(ws);
    if (b == std::string::npos) return NA_INTEGER;
    hms = hms.substr(b, hms.find_last_not_of(ws) - b + 1);

    long long part[3] = {0, 0, 0};
    int ndig[3] = {0, 0, 0};
    int field = 0;
    for (const char c : hms) {
        if (c == ':') {
            if (++field > 2) return NA_INTEGER;
        } else if (c >= '0' && c <= '9' && ndig[field] < 9) {
            part[field] = part[field] * 10 + (c - '0');
            ndig[field]++;
        } else {
            return NA_INTEGER;
        }
    }
    if (field != 2 || ndig[0] == 0 || ndig[1] != 2 || ndig[2] != 2 ||
        part[1] >= 60 || part[2] >= 60) {
        return NA_INTEGER;
    }

    const long long secs = 3600 * part[0] + 60 * part[1] + part[2];
    if (secs > INT_MAX) return NA_INTEGER;
    return static_cast<int>(secs);
}

//' cpp_time_to_seconds
//'
//' Vectorize the above function
//'
//' @noRd
[[cpp11::register]]
integers cpp_time_to_seconds(const strings times_in) {
    const R_xlen_t n = times_in.size();
    const size_t ns = static_cast<size_t>(n);

    std::vector<std::string> times(ns);
    std::copy(times_in.begin(), times_in.end(), times.begin());

    writable::integers res(n);

    for (size_t i = 0; i < ns; i++) {
        if (times[i] == "" || times[i] == "NA") {
            res[i] = na<int>();
        } else {
            res[i] = convert_time_to_seconds(times[i]);
        }
    }

    return res;
}
