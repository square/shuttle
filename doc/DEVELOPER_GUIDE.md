Introduction
============

Shuttle is Square's translation platform and libraries. It scans a project for
localizable content, presents that content to the translators, and then
reintegrates translated strings back into a the project at deploy time. Shuttle
has a suite of **importers** that recognize translatable content in files and
import those translations, **exporters** that generate files containing
translated strings in some known format (e.g., Rails i18n YAML files), and ﻿
**localizers﻿** that generate duplicates of some asset, substituting translated
copy when appropriate (e.g., ﻿iOS xib files).

How to appropriately use Shuttle, or, "What Shuttle is not"
-----------------------------------------------------------

**Shuttle is not a localization or internationalization tool﻿, only 
translation.** You should keep _locale_-specific data, such as date and time
formats, out of Shuttle. (Month names would be appropriate, however.) Use
another library, such as JavaScript's locale settings, for this. Shuttle is only
appropriate for translating strings to other locales.

**Shuttle is not a tool to manage content that differs between countries﻿**. You
should not, for example, use the en-CA locale to store content that only applies
in Canada, such as country-specific transaction rates or legal terms. This
content should appear under a completely different key. The locale "en-CA"
should _only_ ﻿mean "content that has been translated into Canadian English,"
_﻿not﻿_ "content that applies in Canada." Make the distinction between Canada, the
country, and Canadian, the dialect. (For example, a Canadian-American living in
America may wish to see American-specific content but with Canadian spellings.)

**You should not break up translatable copy or use conditional interpolations.**
For example, you should not do this:

```` ruby
t("Sign up to receive your ") + (reader_free? ? t('free') : t('low-cost')) t(" card reader.")
````

This breaks up the translatable string in a way that may not be appropriate for
all locales. Instead, you should consider translatable strings immutable and
atomic:

```` ruby
if reader_free?
  t("Sign up to receive your free card reader.")
else
  t("Sign up to receive your low-cost card reader.")
end
````

You should also avoid interpolating string fragments into your translations. Do
not do this:

```` ruby
t("Sign up to receive your %{pricing} card reader", pricing: reader_free? ? t('free'), t('low-cost'))
````

Instead, see the example above.

**You should avoid duplicating string content when possible, even if that
content is used in two different locations﻿.** The only reason two pieces of
identical content should have different keys is if they are likely to need
different translations in some locales. We have in the past seen, for example,
translators staring at a dozen identical pending translation requests, all with
the content "Alabama." They would have keys like `some-module.state.AL`,
`some-other-module.state.AL`, etc. "Alabama" will probably translate to the same
word in any scenario, regardless of where the string is used, so cut the
translators a break and consolidate the strings. A good counterexample is the
string "Change", which could be a button title (verb) in one context, or a
concept (noun) in another context, and therefore should use separate keys.

**You should avoid trying to be overly clever at saving Shuttle work﻿.**
Shuttle's exporters can remove unnecessary translations or otherwise optimize
output files as necessary. There's no need to try to be clever and do this with
key exclusions and similar.

Using Shuttle
=============

First steps
-----------

To use Shuttle, you need to sign up and be approved. Shuttle uses its own
authentication system as could be open to more than just employees. First you
will need to sign up and have your account approved. An administrator can help
you do this.

Add your project by clicking "Add Project" on the home page. Fill out at a
minimum your project's name and repository URL.

Adding commits
--------------

When your project is ready for translation, you can submit the SHA of a commit
to Shuttle. To do this, click the title of your project to expand it, and enter
the SHA into the field. You can use ref-ishes like `HEAD`.

Shuttle will begin importing the commit and scanning it for translations. The
first time you do this, Shuttle will need to clone the project, which can take
a while for large repositories.

While scanning is in progress, the progress bar will be orange and
zebra-striped. The total number of strings detected in the project (upper right
corner) will count up as new strings are imported. When that completes, Shuttle
will begin generate pending translation requests for each of these strings in
every configured locale. As this happens, the total translations count (shown
in the progress bar) will count up.

When the import completes, the progress bar will return to its normal state. If
you have previously imported a prior commit, Shuttle will detect any
already-approved translations of those strings and, assuming the original
content of the string hasn't changed in this new commit, the translations will
be copied over. In this respect, if you need to make a minor tweak to one or two
strings, you can make th commit, add it to Shuttle, and discover that only a few
translations need to be made before the commit is marked as ready.

Translation process
-------------------

Once a commit has been imported, the translations will be made available to the
translators. When a translation is added, it must be approved by a reviewer.
Once all translations in all _required_ project locales are translated _and_
approved, the commit is considered "ready" and the progress bar will be green.

You can view detailed translation progress by clicking the "Status" button on
the translation detail view. To get to this view, first expand your project by
clicking on its name in the home page, then expand the commit by clicking on the
progress bar.

The status page displays all the imported strings in your project, and the
translations in each of your project's locales. Pending translations are gray,
completed translations are blue, and approved translations are green. Along the
top, required locales are in red, and completed locales appear with a checkmark.

Downloading translations
------------------------

Once a commit is ready, translated files can be downloaded. There are two HTTPS
endpoints you will use to do this. Depending on your project, you will need to
use one or both of them.

### Downloading manifest files

For localization libraries that store their translated strings in one file (this
is most libraries, including Rails i18n, Ember.js, and others), you can download
a manifest file. This file will contain solely translated strings for one or
more locales, depending on the limitations of your localization library.

The intent is for this manifest file to be downloaded as part of your deploy
script, and bundled with your project as a deploy artifact, rather than checked
into the project repository. In addition, the endpoint will return a 404 error
if the commit is not fully localized, allowing you to fail the deploy rather
than inadvertently deploy a finished product that has incomplete translations,
which would be unacceptable for Shuttle's standards of internationalization.

For testing purposes, you can force download of a partial manifest, so you can
preview translations locally or on a staging server.

To download a manifest, use the following endpoint:

`GET /projects/:project_slug/commits/:sha/manifest.:format`

Replace the colon-prefixed placeholders with the following:

|                 |                                                                                                 |
|:----------------|:------------------------------------------------------------------------------------------------|
| `:project_slug` | Your project's URL slug. You can find this by visiting a commit status page and noting the URL. |
| `:sha`          | The full 40-character SHA of the translated commit.                                             |
| `:format`       | The format of the manifest file you wish to download (see below).                               |

The value of `:format` will depend on the localization library you are using:

| Library                        | `:format`    | Notes                                                                                                   |
|:-------------------------------|:-------------|:--------------------------------------------------------------------------------------------------------|
| Android                        | `android`    | Will be a gzipped tarball that can be extracted into your project root.                                 |
| Rails i18n (YAML)              | `yaml`       | All locales will be merged into one file unless the `locale` query parameter is specified.              |
| Ember.js                       | `js`         | All locales will be merged into one file unless the `locale` query parameter is specified.              |
| Ember.js (dependency-injected) | `jsm`        | Similar to Ember.js, but places translations under a `module.exports` object. Locale must be specified. |
| iOS .strings (single file)     | `strings`    | The `locale` query parameter must be specified. File is in UTF-16LE encoding.                           |
| iOS .strings (tarball)         | `ios`        | Will be a gzipped tarball that can be extracted into your project root. Files are in UTF-16LE encoding. |
| Rails i18n (Ruby)              | `rb`         | All locales will be merged into one file unless the `locale` query parameter is specified.              |
| Java Properties                | `properties` | File will be UTF-8 encoded with no escapes.                                                             |

The following query parameters are supported:

|           |                                                                                                                                                                   |
|:----------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `locale`  | Specify the RFC 5646 code of a locale you want to limit the manifest to. A 400 Bad Request response is given if the locale code is not recognized.                |
| `partial` | Set to `true` to allow download of a manifest from a commit that is not yet fully translated. Unapproved translations are included; pending translations are not. |

A normal response status is 200 OK. If the commit is not fully localized and
`partial` is not set,the response status is 404 Not Found. If the value of
`:format` is not recognized, the response status will be 406 Not Acceptable. If
`locale` is required and not provided, the response status is 400 Bad Request.

### Downloading localized files

For localization libraries that expect translated strings to be reintegrated
into duplicated copies of assets (for example, iOS xibs must be duplicated and
localized in each locale), you can download a localized gzipped-tarball that
can be extracted into your project root.

As with the manifest file, the intent is for this file to be downloaded as part
of your deploy process, and bundled with your project as a deploy artifact,
rather than checked into the project repository. Also as with the manifest, a
404 is returned for commits that aren't fully transalted, allowing you to fail
the deploy.

To download a localized tarball, use the following endpoint:

`GET /projects/:project_slug/commits/:sha/localize.tgz`

Replace the colon-prefixed placeholders with the following:

|                 |                                                                                                 |
|:----------------|:------------------------------------------------------------------------------------------------|
| `:project_slug` | Your project's URL slug. You can find this by visiting a commit status page and noting the URL. |
| `:sha`          | The full 40-character SHA of the translated commit.                                             |

Note that you do not have to specify the output format. All appropriate
localizers will be used to generate the tarball.

The following query parameters are supported:

|           |                                                                                                                                                                  |
|:----------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `locale`  | Specify the RFC 5646 code of a locale you want to limit the tarball to. A 400 Bad Request response is given if the locale code is not recognized.                |
| `partial` | Set to `true` to allow download of a tarball from a commit that is not yet fully translated. Unapproved translations are included; pending translations are not. |

### Webhooks

You may want to add additional functionality to Shuttle. For example when a
commit is ready you may want an email or to kick off a CI build. A lot of this
functionality can be built using Shuttle's Webhooks. For now, when a commit
flips from not-ready to ready, Shuttle will ping the URL defined in the project
settings. The post body will contain something like

```` json
{
    "commit_revision": "b902bacd58d386e7d3a55e67c8dcbaf19a3cd9c8",
    "project_name": "Help Center",
    "ready": "true"
}
````

### Integrating Shuttle into a branch-based deploy pipeline

Shuttle projects have two settings, "watched branches" and "touchdown branch,"
used to build branch-based workflows that integrate with CI or CD. Let's assume
that you land all pull requests on the "master" branch, and master is always
considered ready for continuous integration. Let's further you had a CI machine
that watches master, and updates a "green" branch when specs pass. Presumably,
your CD machine would then watch the green branch and deploy when it's updated.

Now you want to add Shuttle to this pipeline. If you wanted to add Shuttle
before the CI step, you would set "watched branches" to `master` and "touchdown
branch" to, say, `translated`. You'd then set your CI machine to watch
`translated` instead of `master`.

**Important note:** The _first_ of the watched branches is considered to be
paired with the touchdown branch. Only commits on that first watched branch will
advance the touchdown branch when translated. Other watched branches can be used
to, e.g., continuously translate an in-progress feature branch, but these
branches will not affect the touchdown branch when translated.

If you wanted to add Shuttle _after_ the CI step, you would set "watched
branches" to `green` and "touchdown branch" to, say, `deployable`. You'd then
set your CD machine to watch `deployable` instead of `green`.

Tuning Shuttle
==============

Once you're comfortable with Shuttle integration in your project, it's time to
start tuning Shuttle so it can be faster. Shuttle can take around half an hour
to perform a full, naïve import on a large project, which can significantly
impact your development cadence. Follow this guide to ensure that you have fast
turnaround time between commit and deploy.

Firstly, go to the settings page for your project (find your project at the
Shuttle home page and click the edit icon). You'll want to pay attention to the
following settings:

**Everything under "Path whitelisting and blacklisting"**: The biggest
optimization you can make is to restrict importers to scanning only certain
directories. If, for example, all your localizable copy is under
`config/locales`, add that path under "only search for strings under these
paths" anf you will see a significant speed improvement for a large project.

**don't use these importers**: Leave unchecked only those importers you actually
care about. For example, a Rails project would check all but the two Rails I18n
importers.

**Precompilation and caching**: At deploy time, you are either downloading a
manifest in one or more specific formats, or a localized tarball, or both,
depending on your project's needs. You can have Shuttle precompile these assets
and cache them so they are immediately available. Shuttle begins this
precompilation any time the commit is marked as ready, and clears the cache any
time a translation is modified. Choose the exporters you wish to pre-generate
manifests for, and select localizer caching if you are using a localized
tarball.

The Future
==========

Ultimately it is untenable to support such a heterogeneous set of localization
libraries, especially when each of them supports a different subset of our
needs. To rectify this, Square intends to introduce our own cross-platform
localization client platform, currently called "NT", that will meet our specific
needs.

NT will work similarly to iOS's `genstrings` tool, in that developers will wrap
localizable content in a sentinel method (similar to `NSLocalizedString`) along
with content. String keys will be generated from the string's content and
context. Importers will scan source and asset files for this sentinel and parse
out strings. In production, the method will substitute translated copy for the
original.

Because of this, it becomes doubly important to ensure that you do not get too
clever with the use of your strings. Metaprogramming with the sentinel method,
or splitting it across multiple lines, or nesting interpolations within, will
prevent the importer from recognizing the method call and importing the string.
To future-proof your application for NT, you should consider localized strings
to be atomic constants, and keep logic and cleverness outside the usage of these
strings.
