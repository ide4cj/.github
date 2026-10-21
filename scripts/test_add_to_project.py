"""Board enrollment must preserve the scope across repository pages."""

import unittest
from unittest.mock import patch

import add_to_project


class RepositoriesTest(unittest.TestCase):
    def test_excludes_p2cj_across_pages_without_losing_other_repositories(self):
        pages = [
            {"nodes": [
                {"name": "cjls", "hasIssuesEnabled": True},
                {"name": "disabled", "hasIssuesEnabled": False},
            ], "pageInfo": {"hasNextPage": True, "endCursor": "next"}},
            {"nodes": [
                {"name": "p2cj", "hasIssuesEnabled": True},
                {"name": "cangjie.nvim", "hasIssuesEnabled": True},
            ], "pageInfo": {"hasNextPage": False, "endCursor": None}},
        ]
        with patch.object(add_to_project, "graphql", side_effect=[
            {"organization": {"repositories": page}} for page in pages
        ]) as graphql:
            self.assertEqual(add_to_project.repositories(), ["cangjie.nvim", "cjls"])
        self.assertEqual(graphql.call_args_list[1].kwargs["after"], "next")


if __name__ == "__main__":
    unittest.main()
