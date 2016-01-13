
window.onload = function() {
    var b = document.body.innerHTML;
    // add breaks for descriptions that are not html markup
    if (!b.match(/<\/p>/g)) {
        var nb = b.replace(/\s(https?:\/\/[a-zA-Z\d\.\-]+\.[a-zA-Z]{2,15}([\/\w-]*)*\/?\??([^#\n\r\s]*)?#?([^\n\r\s<]*))/g, ' <a href="$1">$1</a>').replace(/\n/g, '<br>');
        document.body.innerHTML = nb;
        
    }
}