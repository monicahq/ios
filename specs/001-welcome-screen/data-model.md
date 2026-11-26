# Data Model: Welcome Screen

No persisted data in this feature.

## Instance

The Monica server the app will talk to.

| Field | Type | Rule |
| --- | --- | --- |
| url | text | Absolute `http` or `https` address. In this feature always the default, `https://app.monicahq.com`. |
| host (derived) | text | The url without its scheme and without a trailing slash: `https://app.monicahq.com/` → `app.monicahq.com`. Keeps a port or a path (`http://localhost:8000/monica` → `localhost:8000/monica`). |

Changing the instance (the sheet of the design) and storing the choice are a later feature.

## Strings

Every text of the screen, in each supported language, in `Monica/Resources/Localizable.xcstrings`.
Keys are shared by all languages, and with the Android app.

| Key | English (source) | French |
| --- | --- | --- |
| `app_name` | Monica | Monica |
| `welcome_title` | Welcome to Monica | Bienvenue dans Monica |
| `welcome_description` | Monica helps you remember and organise your relationships and life context. | Monica vous aide à vous souvenir et à organiser vos relations et votre contexte de vie. |
| `welcome_sign_up` | Sign up | Inscription |
| `welcome_log_in` | Log in | Connexion |
| `welcome_instance` | Instance: %@ | Instance : %@ (with a non-breaking space before the colon) |
| `welcome_instance_settings` | Instance settings | Paramètres de l'instance |
| `welcome_illustration` | A panda sitting in the grass, waving | Un panda assis dans l'herbe qui fait coucou |

`app_name` is the same in both languages but listed in each: iOS shows the key itself, not the
English text, when a language's table lacks it. The placeholder string `welcome` ("Welcome to
Monica") is removed.
