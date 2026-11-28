# Features

Chronological list of every feature and improvement. Maintained with the `feature-documentator` skill.

* App: Added the welcome screen, in English and French, with the Monica light and dark theme.
* App: Added the instance sheet to choose the Monica server, kept on the device.
* App: Log in and sign up on the official or a self-hosted Monica, through the instance's own pages in iOS's sign-in sheet; the session stays signed in, renews itself and can be logged out, and saving an instance checks it first. Release builds only talk to HTTPS instances.
* Vaults: Logging in or signing up now opens the list of your vaults, with each vault's colour, initial, name, number of contacts and the default badge, in Liquid Glass.
* Vaults: Added the empty state for an account with no vault, with a button to create the first one.
* Vaults: Pull down, or use the Refresh action, to reload the list.
* Vaults: Tapping a vault opens a first vault screen with its name and description.
* Vaults/new: Added creating a vault with a name, a description, one of the eight colours and the default choice, showing the instance's own message when it refuses.
* Account: Your initials open a sheet with your name, the instance, instance settings and log out, replacing the placeholder home.
* Vaults: The list of vaults and each vault open at once from a copy kept on the phone, then update from the instance.
* Vaults: Without a connection, the list and every vault stay readable, with "Not up to date. Last updated 3 hours ago."
* App: The copy kept on the phone is protected, never backed up, and erased at every sign-out, instance switch or ended session, and after 30 days without reaching the instance.
