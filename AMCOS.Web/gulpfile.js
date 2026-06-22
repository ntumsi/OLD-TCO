console.log("Starting GulpFile");
// Dependencies
const del = require('del');
const { src, dest, series } = require('gulp');
const concat = require('gulp-concat');
const uglify = require('gulp-uglify');
const pump = require('pump');
const babel = require('gulp-babel');

var config = {
    clean: ['dist/css', 'dist/js'],
    babel: {
        presets: [
            "@babel/preset-env"
        ]
    }
};

function clean() {
    return del(config.clean);
}

function copyImages() {
    return src('src/img/**')
        .pipe(dest('dist/img/'));
}

function copyAmcosCSS() {
    return src('src/css/AMCOS.css')
        .pipe(dest('dist/css'));
}

function copyAmcosLiteChartCSS() {
    return src('src/css/amcos-lite-chart.css')
        .pipe(dest('dist/css'));
}

function copyAmcosLiteJS() {
    return src('src/js/amcos-lite.js')
        .pipe(dest('dist/js'));
}

function copyProjectManagerJS() {
    return src('src/js/project-manager.js')
        .pipe(dest('dist/js'));
}

function copyPCSCommonJS() {
    src('src/js/pcs-common.js').pipe(dest('dist/js'));
    return src('src/js/pcs-civilian.js').pipe(dest('dist/js'));
}

function copyAmcosSiteJS() {
    return src('src/js/amcos-site.js')
        .pipe(dest('dist/js'));
}

function minimizeObjectInflationYear(cb) {
    pump([
        src('src/js/object-inflationyear.js'),
        concat('object-inflationyear.min.js'),
        dest('dist/js'),
        uglify(),
        dest('dist/js')
    ],
        cb
    );
}

function minimizeObjectPayPlan(cb) {
    pump([
        src('src/js/object-payplan.js'),
        concat('object-payplan.min.js'),
        dest('dist/js'),
        uglify(),
        dest('dist/js')
    ],
        cb
    );
}

function copyC3JS() {
    return src('node_modules/c3/c3.min.js')
        .pipe(dest('dist/js'));
}

function copyC3CSS() {
    return src('node_modules/c3/c3.min.css')
        .pipe(dest('dist/css'));
}

function copyD3() {
    return src('node_modules/d3/d3.min.js')
        .pipe(dest('dist/js'));
}

function copyFoundationSitesJS() {
    return src('node_modules/foundation-sites/dist/js/foundation.min.js')
        .pipe(dest('dist/js'));
}

function copyFoundationSitesCSS() {
    return src('node_modules/foundation-sites/dist/css/foundation.min.css')
        .pipe(dest('dist/css'));
}

function copyjQuery() {
    return src('node_modules/jquery/dist/jquery.min.js')
        .pipe(dest('dist/js'));
}

function copySelectizeDefaultCSS() {
    return src('node_modules/selectize/dist/css/selectize.default.css')
        .pipe(dest('dist/css'));
}

function copySelectizeJS() {
    return src('node_modules/selectize/dist/js/standalone/selectize.min.js')
        .pipe(dest('dist/js'));
}

function copyWhatInput() {
    return src('node_modules/what-input/dist/what-input.min.js')
        .pipe(dest('dist/js'));
}

function copyAmcosCommonJS() {    
    return src('src/js/amcos-common.js').pipe(babel(config.babel)).pipe(dest('dist/js'));
}
function copyQuicksightJS() {
    return src(['src/js/quicksight.js', 'node_modules/amazon-quicksight-embedding-sdk/dist/quicksight-embedding-js-sdk.min.js']).pipe(dest('dist/js'));
}
exports.default = series(
    clean,
    copyImages,
    copyC3CSS,
    copyC3JS,
    copyD3,
    copyFoundationSitesCSS,
    copyFoundationSitesJS,
    copyjQuery,
    copySelectizeDefaultCSS,
    copySelectizeJS,
    copyWhatInput,
    copyAmcosCSS,
    copyAmcosLiteChartCSS,
    copyAmcosCommonJS,
    copyAmcosLiteJS,
    copyAmcosSiteJS,
    copyProjectManagerJS,
    copyPCSCommonJS,
    minimizeObjectInflationYear,
    minimizeObjectPayPlan, 
    copyQuicksightJS
);

exports.copyAmcosLiteJs = series(
    copyAmcosCommonJS,
    copyAmcosLiteJS
);

exports.copyProjectManagerJs = series(
    copyAmcosCommonJS,
    copyProjectManagerJS
);

exports.copyPCSJs = series(
    copyPCSCommonJS
);

exports.rollupTest = series(
    copyAmcosCommonJS
);
