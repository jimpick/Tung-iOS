# Tung.fm for iOS
[Tung.fm](https://tung.fm) for iOS - a social podcast player

> Discover podcasts by sharing comments, clips, and recommendations with your friends.

This repo is for the iOS app. See also:
- [Tung API repo](https://github.com/inorganik/Tung-API)
- [Tung.fm repo](https://github.com/inorganik/tung.fm)

Hello! Tung is a full featured podcast app with some special abilities. Make contributions, borrow code, or create a new client for the Tung API. I'll moderate pull requests and make sure merged code gets into new releases.

[View Tung on the App Store](https://itunes.apple.com/us/app/tung.fm/id932939338)

View releases here: https://tung.fm/releases

### Contributing

Notably absent from source control is a file called `secrets.json` which contains keys for Twitter and a Tung API key. You'll need to create this file to run the app. You can create your own twitter app and get the necessary keys. [Contact me](jamie.perkins@gmail.com) and I can get you a Tung API key (which is only needed for certain requests). The secrets file should look like this:

```json
{
    "tungApiKey": "XXX",
    "twitter": {
        "consumerKey": "XXX",
        "consumerSecret": "XXX"
    }
}
```

### Backstory

#### In the beginning...
Tung is a passion project I started in January of 2014. It began as a sound clip sharing app that let you record sounds and share them to your friends. After releasing a beta, I quickly realized that content quality was an issue, not to mention motivating people to create content at all. With this problem, and the advent of other clip-sharing apps emerging, I pivoted. I was already a huge fan of podcasts and podcasts are generally well-produced and are very clip worthy. Also, discovery was hard. So I set out to reinvent Tung as a way to discover podcasts, by allowing users to recommend, comment on and make clips from podcasts. All this would appear in a feed that would help you discover podcasts.

#### Release 
I released Tung to the App Store on 7/22/2016. Despite being a huge personal accomplishment for me to ship it myself, with no funding, it only received just under 100 upvotes on Product Hunt. I also had less than 50 beta testers. Why did this matter? Much of the value of Tung lies in the network effect, and you have to reach a critical mass of users for the network effect to be realized. Despite having a group of loyal users, Tung didn't organically grow to reach that critical mass.

#### Today
Tung is a full-featured podcast player with some special and unique abilities. Despite debuting a year before the [YC-backed competition](https://breaker.audio/) that also positions itself as a social podcast player, it hasn't reached the critical mass of users. But Tung remains my favorite podcast player (I'm not biased 😄) and I still discover new podcasts on it. 
