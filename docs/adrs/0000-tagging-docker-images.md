# Tagging Inspec scanner docker images

For the Inspec scanner Docker images, we will want to be able to tag
them so that users can lock them to a specific version if necessary as
well as tell at a glance which version of the image they are using.
This ADR will discuss how we will tag these images.

## Date

2021-02-11

## Status

Accepted

## Author(s)

@cblkwell

## Considered Alternatives

* Tag with semantic versioning
* Tag by date
* Tag by git SHA
* Combination of above

## Decision Outcome

We will tag docker images by date and git SHA, as well as tagging the
most recent image with `latest`.

## Consequences

Users will be able to lock images to a date or specific git SHA if they
need to freeze the version they are using, or simply use the latest image
if they want to accept the risk of automatic updates.

## Pros and Cons of the Alternatives <!-- optional -->

### Tag with semantic versioning

* `+` Images will be easily distinguishable by tag
* `-` Tag is not easily tied to a specific date

### Tag by date

* `+` Images will be easily distinguishable by tag
* `+` Tag is easily tied to specific date

### Tag by git SHA

* `+` Images will be easily distinguishable by tag
* `+` Easy to verify tag corresponds to image
* `-` Tag is not easily tied to specific date

### Combination (date and SHA tagging)

* `+` Images will be easily distinguishable by tag
* `+` Easy to verify tag corresponds to image
* `+` Tag easily matched to specific date
