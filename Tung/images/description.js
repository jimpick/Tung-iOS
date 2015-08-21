
window.onload = function() {
    var b = document.body.innerHTML;
    // add breaks for descriptions that are not html markup
    if (!b.match(/<\/p>/g)) {
        var nb = b.replace(/\n/g, '<br>');
        document.body.innerHTML = nb;
    }
}