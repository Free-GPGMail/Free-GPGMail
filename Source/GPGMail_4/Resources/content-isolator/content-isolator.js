;
window.ContentIsolatorMainFrame = true;
document.querySelector('html').classList.add('content-isolator');
document.querySelectorAll('.content-isolator__isolated-content').forEach(iframe =>  {
    iframe.onload = () => {
        iFrameResize({
            log: false,
            checkOrigin: false,
            bodyPadding: '0px',
            bodyMargin: '0px',
            heightCalculationMethod: 'taggedElement'
        }, iframe);
    }
    iframe.src = iframe.getAttribute('data-src');
});
