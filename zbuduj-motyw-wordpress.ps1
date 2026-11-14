# Buduje motyw WordPress "maciektrener40plus" z plików strony (index.html, style.css, script.js, img/)
# Wynik: wordpress\maciektrener40plus.zip  -> wgraj w WordPress: Wygląd > Motywy > Dodaj nowy > Wyślij motyw na serwer
# Uruchom ponownie po każdej zmianie strony, potem wgraj nowy ZIP (WordPress zapyta o zastąpienie motywu).
#
# Motyw:
#   front-page.php  strona główna (sekcje z index.html; w Kontakcie formularz WPForms, jeśli wtyczka jest włączona)
#   index.php       Artykuły (lista wpisów), pojedynczy wpis, zwykłe strony, archiwa, 404
#   header.php / footer.php  wspólny nagłówek i stopka (linki do sekcji prowadzą na stronę główną)

$ErrorActionPreference = 'Stop'
$root   = $PSScriptRoot
$slug   = 'maciektrener40plus'
$formId = 17   # numer formularza WPForms ("Prosty formularz kontaktowy")
$outDir = Join-Path $root 'wordpress'
$build  = Join-Path $outDir $slug
$zip    = Join-Path $outDir "$slug.zip"
$utf8   = New-Object System.Text.UTF8Encoding($false)
function Save($name, $text) { [IO.File]::WriteAllText((Join-Path $build $name), $text, $utf8) }

if (Test-Path $build) { Get-ChildItem $build -Force | Remove-Item -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $build 'img') | Out-Null

# 1) style.css z nagłówkiem motywu
$header = @"
/*
Theme Name: Maciej Erdon - Trener Personalny 40+
Theme URI: https://maciektrener40plus.pl/
Author: Maciej Erdon
Description: Motyw strony trenera personalnego (trening funkcjonalny 40+, oferta online, plany treningowe, przepisy, artykuły).
Version: 2.0.$(Get-Date -Format 'yyMMddHHmm')
Requires at least: 6.0
Requires PHP: 7.4
Text Domain: $slug
*/

"@
Save 'style.css' ($header + [IO.File]::ReadAllText((Join-Path $root 'style.css'), $utf8))

# 2) index.html -> podział na nagłówek / treść strony głównej / stopkę
$html = [IO.File]::ReadAllText((Join-Path $root 'index.html'), $utf8)
$uri  = '<?php echo esc_url( get_template_directory_uri() ); ?>'
$homeUrl = '<?php echo esc_url( home_url( ''/'' ) ); ?>'

# najpierw zmiany w <head> (zanim w adresach pojawią się znaczniki PHP z ">")
$html = $html -replace '\s*<title>.*?</title>', ''
$html = $html -replace '(?s)(\s*<meta name="description".*?<meta property="og:image"[^>]*>)', "`r`n  <?php if ( ! mt40_seo_plugin() ) : ?>`$1`r`n  <?php endif; ?>"
$html = $html -replace '(<link rel="preload" as="image"[^>]*>)', '<?php if ( is_front_page() ) : ?>$1<?php endif; ?>'
$html = $html -replace '(?s)(<script type="application/ld\+json">.*?</script>)', '<?php if ( is_front_page() ) : ?>$1<?php endif; ?>'

# ?ver=<data pliku> — po każdej aktualizacji motywu przeglądarki i cache serwera pobiorą nowe pliki
$html = $html.Replace('href="style.css"', 'href="<?php echo esc_url( get_stylesheet_uri() . ''?ver='' . filemtime( get_stylesheet_directory() . ''/style.css'' ) ); ?>"')
$html = $html.Replace('src="script.js"', 'src="<?php echo esc_url( get_template_directory_uri() . ''/script.js?ver='' . filemtime( get_template_directory() . ''/script.js'' ) ); ?>"')
$html = $html -replace '(src|href|content)="img/', "`$1=""$uri/img/"
$html = $html.Replace('"image": "img/', """image"": ""$uri/img/")
# link "Artykuły" -> strona wpisów ustawiona w WordPressie
$html = $html -replace 'href="[^"]*"([^>]*)data-wp-link="artykuly"', 'href="<?php echo esc_url( mt40_articles_url() ); ?>"$1data-wp-link="artykuly"'

$iMain    = $html.IndexOf('<main id="main">')
$iMainEnd = $html.IndexOf('</main>')
if ($iMain -lt 0 -or $iMainEnd -lt 0) { throw 'Nie znaleziono <main id="main"> w index.html' }
$top    = $html.Substring(0, $iMain)
$main   = $html.Substring($iMain, $iMainEnd + 7 - $iMain)
$bottom = $html.Substring($iMainEnd + 7)

# -- header.php: tytuł/opis daje WordPress (Rank Math, jeśli jest), linki z "#" prowadzą na stronę główną
$top = $top -replace 'href="#(?!main")', "href=""$homeUrl#"
$top = $top.Replace('<html lang="pl">', '<html <?php language_attributes(); ?>>')
$top = $top.Replace('</head>', "  <?php wp_head(); ?>`r`n</head>")
$top = $top.Replace('<body>', '<body <?php body_class(); ?>>' + "`r`n  <?php wp_body_open(); ?>")
Save 'header.php' $top

# -- footer.php
$bottom = $bottom.Replace('href="#">Polityka prywatności', 'href="<?php echo esc_url( mt40_privacy_url() ); ?>">Polityka prywatności')
$bottom = $bottom -replace 'href="#', "href=""$homeUrl#"
$bottom = $bottom.Replace('</body>', "  <?php wp_footer(); ?>`r`n</body>")
Save 'footer.php' $bottom

# -- front-page.php: formularz WPForms zamiast statycznego (statyczny zostaje jako zapas)
$wpForm = @"
<?php if ( shortcode_exists( 'wpforms' ) ) : ?>
        <div class="form form--wp" id="contact-form-wp">
          <?php echo do_shortcode( '[wpforms id="$formId" title="false" description="false"]' ); ?>
        </div>
        <?php else : ?>
        `$0
        <?php endif; ?>
"@
$main = [regex]::Replace($main, '(?s)<form class="form" id="contact-form".*?</form>', { param($m) $wpForm.Replace('$0', $m.Value) })
Save 'front-page.php' ("<?php get_header(); ?>`r`n`r`n  " + $main + "`r`n`r`n<?php get_footer(); ?>`r`n")

# 3) index.php — artykuły, wpisy, strony, archiwa, 404
Save 'index.php' @'
<?php get_header(); ?>

  <main id="main" class="page-wrap">
    <div class="container">

    <?php if ( is_singular() ) : ?>
      <?php while ( have_posts() ) : the_post(); ?>
      <article <?php post_class( 'entry' ); ?>>
        <?php if ( is_single() ) : ?>
          <a class="entry__back" href="<?php echo esc_url( mt40_articles_url() ); ?>">← Wszystkie artykuły</a>
          <p class="entry__meta"><?php echo esc_html( get_the_date() ); ?> · <?php echo esc_html( mt40_reading_time() ); ?></p>
        <?php endif; ?>
        <h1 class="entry__title"><?php the_title(); ?></h1>
        <?php if ( has_post_thumbnail() ) : ?>
          <figure class="entry__thumb"><?php the_post_thumbnail( 'large' ); ?></figure>
        <?php endif; ?>
        <div class="entry__content"><?php the_content(); ?></div>
        <?php wp_link_pages(); ?>

        <?php if ( is_single() ) : ?>
        <aside class="entry__cta">
          <h2>Chcesz trenować bezpiecznie i skutecznie?</h2>
          <p>Umów bezpłatną konsultację — dobierzemy plan do Twojego wieku, celu i możliwości.</p>
          <a class="btn btn--primary" href="<?php echo esc_url( home_url( '/#kontakt' ) ); ?>">Umów konsultację</a>
        </aside>
        <nav class="post-nav" aria-label="Kolejne artykuły">
          <span><?php previous_post_link( '%link', '← %title' ); ?></span>
          <span><?php next_post_link( '%link', '%title →' ); ?></span>
        </nav>
        <?php endif; ?>
      </article>
      <?php endwhile; ?>

    <?php else : ?>
      <header class="section__head">
        <p class="eyebrow"><?php echo is_search() ? 'Wyniki wyszukiwania' : 'Wiedza'; ?></p>
        <h1 class="section__title"><?php echo esc_html( mt40_archive_title() ); ?></h1>
        <p class="section__lead">Trening, regeneracja i odżywianie po 40. — praktycznie, bez mitów i bez ściemy.</p>
      </header>

      <?php if ( have_posts() ) : ?>
        <div class="posts">
        <?php while ( have_posts() ) : the_post(); ?>
          <article <?php post_class( 'post-card' ); ?>>
            <?php if ( has_post_thumbnail() ) : ?>
              <a class="post-card__thumb" href="<?php the_permalink(); ?>" tabindex="-1" aria-hidden="true"><?php the_post_thumbnail( 'medium_large' ); ?></a>
            <?php endif; ?>
            <div class="post-card__body">
              <p class="post-card__meta"><?php echo esc_html( get_the_date() ); ?> · <?php echo esc_html( mt40_reading_time() ); ?></p>
              <h2 class="post-card__title"><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h2>
              <p class="post-card__excerpt"><?php echo esc_html( wp_trim_words( get_the_excerpt(), 28 ) ); ?></p>
              <a class="post-card__more" href="<?php the_permalink(); ?>">Czytaj dalej →</a>
            </div>
          </article>
        <?php endwhile; ?>
        </div>
        <div class="pagination"><?php echo paginate_links( array( 'prev_text' => '←', 'next_text' => '→' ) ); ?></div>
      <?php else : ?>
        <p class="posts__empty">Nie ma tu jeszcze artykułów. Zajrzyj wkrótce!</p>
      <?php endif; ?>
    <?php endif; ?>

    </div>
  </main>

<?php get_footer(); ?>
'@

# 4) functions.php
Save 'functions.php' @'
<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

add_action( 'after_setup_theme', function () {
	add_theme_support( 'title-tag' );
	add_theme_support( 'post-thumbnails' );
	add_theme_support( 'html5', array( 'search-form', 'gallery', 'caption', 'style', 'script' ) );
	add_theme_support( 'responsive-embeds' );
} );

/** Czy działa wtyczka SEO (wtedy ona daje tytuły, opisy i znaczniki og:) */
function mt40_seo_plugin() {
	return defined( 'RANK_MATH_VERSION' ) || defined( 'WPSEO_VERSION' ) || defined( 'AIOSEO_VERSION' );
}

/** Adres strony "Artykuły" (strona wpisów z Ustawienia > Czytanie) */
function mt40_articles_url() {
	$id = (int) get_option( 'page_for_posts' );
	return $id ? get_permalink( $id ) : home_url( '/artykuly/' );
}

/** Adres polityki prywatności (Ustawienia > Prywatność), inaczej "#" */
function mt40_privacy_url() {
	$url = get_privacy_policy_url();
	return $url ? $url : home_url( '/#' );
}

/** Szacowany czas czytania */
function mt40_reading_time() {
	$words = str_word_count( wp_strip_all_tags( get_post_field( 'post_content', get_the_ID() ) ) );
	return max( 1, (int) ceil( $words / 200 ) ) . ' min czytania';
}

function mt40_archive_title() {
	if ( is_home() ) {
		$id = (int) get_option( 'page_for_posts' );
		return $id ? get_the_title( $id ) : 'Artykuły';
	}
	if ( is_search() ) { return 'Szukasz: ' . get_search_query(); }
	if ( is_404() ) { return 'Nie znaleziono strony'; }
	return wp_strip_all_tags( get_the_archive_title() );
}

/** Tytuł strony głównej (gdy strona główna to np. "Sample Page") */
$mt40_front_title = function ( $title ) {
	return is_front_page() ? 'Maciej Erdon — Trener personalny Morąg | Trening funkcjonalny 40+' : $title;
};
add_filter( 'pre_get_document_title', $mt40_front_title, 99 );
add_filter( 'rank_math/frontend/title', $mt40_front_title, 99 );
add_filter( 'rank_math/frontend/description', function ( $d ) {
	return is_front_page()
		? 'Maciej Erdon – akredytowany trener personalny (REPs Polska, EQF 3). Trening funkcjonalny i diagnostyka ruchowa dla osób 40+, prowadzenie online i przygotowanie do testów sprawnościowych służb mundurowych.'
		: $d;
}, 99 );

// Bez emoji WordPressa (szybsze ładowanie)
remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
remove_action( 'wp_print_styles', 'print_emoji_styles' );

// Pasek administratora nie zasłania przyklejonego nagłówka
add_action( 'wp_head', function () {
	if ( is_admin_bar_showing() ) {
		echo '<style>.header{top:var(--wp-admin--admin-bar--height,32px)}</style>';
	}
} );
'@

# 5) skrypt, zdjęcia, miniatura motywu
Copy-Item (Join-Path $root 'script.js') $build
Get-ChildItem (Join-Path $root 'img') -File |
  Where-Object { $_.Name -notmatch ' ' } |
  ForEach-Object { Copy-Item $_.FullName (Join-Path $build 'img') }
Copy-Item (Join-Path $root 'img\trening-kettlebell.jpg') (Join-Path $build 'screenshot.jpg')

# 6) ZIP (ukośniki "/" w ścieżkach — wymagane przez WordPress)
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip -Force }
$archive = [IO.Compression.ZipFile]::Open($zip, 'Create')
try {
  Get-ChildItem $build -Recurse -File | ForEach-Object {
    $rel = $slug + '/' + $_.FullName.Substring($build.Length + 1).Replace('\', '/')
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $rel, 'Optimal') | Out-Null
  }
} finally { $archive.Dispose() }

"Gotowe: $zip ($([math]::Round((Get-Item $zip).Length/1KB)) KB)"
