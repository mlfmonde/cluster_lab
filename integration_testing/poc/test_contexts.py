import requests
# no need to import contexts!

class WhenRequestingAResourceThatDoesNotExist:
    def given_that_we_are_asking_for_a_made_up_resource(self):
        self.uri = "https://www.github.com/itdontexistman"
        self.session = requests.Session()

    def because_we_make_a_request(self):
        self.response = self.session.get(self.uri)

    def the_response_should_have_a_status_code_of_404(self):
        assert self.response.status_code == 404

    def the_response_should_have_an_HTML_content_type(self):
        assert self.response.headers['content-type'] == 'text/plain; charset=utf-8'

    def cleanup_the_session(self):
        self.session.close()