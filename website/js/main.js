/**
 * NovoJogo Landing Page - Main JavaScript
 * Vanilla JS, no dependencies
 * Performance-optimized with IntersectionObserver and RAF
 */

(function() {
  'use strict';

  // Configuration
  const CONFIG = {
    scrollThreshold: 50,
    revealThreshold: 0.15,
    mobileBreakpoint: 768,
    parallaxStrength: 0.4,
  };

  // DOM Elements (cached)
  let navbar = null;
  let menuToggle = null;
  let hero = null;
  let navLinks = null;
  let sections = null;

  // State
  let isParallaxEnabled = true;
  let ticking = false;

  /**
   * Initialize all features when DOM is ready
   */
  function init() {
    cacheDOM();
    setupScrollReveal();
    setupNavbarScroll();
    setupSmoothScroll();
    setupMobileMenu();
    setupParallax();
    setupActiveSectionHighlight();
  }

  /**
   * Cache DOM elements for performance
   */
  function cacheDOM() {
    navbar = document.querySelector('.navbar');
    menuToggle = document.querySelector('.navbar-toggle');
    hero = document.getElementById('hero');
    navLinks = document.querySelectorAll('a[href^="#"]');
    sections = document.querySelectorAll('section[id]');
  }

  /**
   * 1. Scroll Reveal - IntersectionObserver for fade-in animations
   */
  function setupScrollReveal() {
    const revealElements = document.querySelectorAll('.reveal');

    if (!revealElements.length) return;

    const revealObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            revealObserver.unobserve(entry.target);
          }
        });
      },
      { threshold: CONFIG.revealThreshold }
    );

    revealElements.forEach(el => revealObserver.observe(el));
  }

  /**
   * 2. Navbar Scroll Effect - Add class on scroll past threshold
   */
  function setupNavbarScroll() {
    if (!navbar) return;

    function updateNavbar() {
      if (window.scrollY > CONFIG.scrollThreshold) {
        navbar.classList.add('scrolled');
      } else {
        navbar.classList.remove('scrolled');
      }
    }

    window.addEventListener('scroll', updateNavbar, { passive: true });
    updateNavbar(); // Initial check
  }

  /**
   * 3. Smooth Scroll - Native smooth scrolling for anchor links
   */
  function setupSmoothScroll() {
    if (!navLinks.length) return;

    navLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        const href = link.getAttribute('href');

        // Skip if external or just "#"
        if (!href || href === '#' || href.startsWith('http')) return;

        const targetId = href.substring(1);
        const targetElement = document.getElementById(targetId);

        if (targetElement) {
          e.preventDefault();

          // Close mobile menu if open
          if (navbar && navbar.classList.contains('nav-open')) {
            navbar.classList.remove('nav-open');
          }

          // Smooth scroll to target
          targetElement.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
          });

          // Update URL without jumping
          history.pushState(null, '', href);
        }
      });
    });
  }

  /**
   * 4. Mobile Menu Toggle - Handle hamburger menu
   */
  function setupMobileMenu() {
    if (!menuToggle || !navbar) return;

    // Toggle menu on button click
    menuToggle.addEventListener('click', (e) => {
      e.stopPropagation();
      navbar.classList.toggle('nav-open');
    });

    // Close menu on click outside
    document.addEventListener('click', (e) => {
      if (navbar.classList.contains('nav-open')) {
        if (!navbar.contains(e.target)) {
          navbar.classList.remove('nav-open');
        }
      }
    });

    // Close menu on ESC key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && navbar.classList.contains('nav-open')) {
        navbar.classList.remove('nav-open');
      }
    });
  }

  /**
   * 5. Parallax Hero - Subtle background movement on scroll
   */
  function setupParallax() {
    if (!hero) return;

    // Check if parallax should be enabled
    function checkParallaxState() {
      isParallaxEnabled = window.innerWidth >= CONFIG.mobileBreakpoint;
    }

    // Apply parallax transform
    function applyParallax() {
      if (!isParallaxEnabled) {
        hero.style.backgroundPositionY = '';
        return;
      }

      const scrolled = window.scrollY;
      const offset = scrolled * CONFIG.parallaxStrength;
      hero.style.backgroundPositionY = `${offset}px`;
    }

    // Throttle scroll handler with requestAnimationFrame
    function onScroll() {
      if (!ticking) {
        window.requestAnimationFrame(() => {
          applyParallax();
          ticking = false;
        });
        ticking = true;
      }
    }

    // Initial setup
    checkParallaxState();
    applyParallax();

    // Event listeners
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', () => {
      checkParallaxState();
      applyParallax();
    }, { passive: true });
  }

  /**
   * 7. Active Nav Link - Highlight based on current section
   */
  function setupActiveSectionHighlight() {
    if (!sections.length || !navLinks.length) return;

    const navLinkMap = new Map();

    // Create mapping of section IDs to nav links
    navLinks.forEach(link => {
      const href = link.getAttribute('href');
      if (href && href.startsWith('#')) {
        const sectionId = href.substring(1);
        navLinkMap.set(sectionId, link);
      }
    });

    // Observer callback
    const sectionObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          const sectionId = entry.target.id;
          const navLink = navLinkMap.get(sectionId);

          if (!navLink) return;

          if (entry.isIntersecting) {
            // Remove active from all links
            navLinks.forEach(link => link.classList.remove('active'));
            // Add active to current section link
            navLink.classList.add('active');
          }
        });
      },
      {
        threshold: 0.3,
        rootMargin: '-10% 0px -70% 0px'
      }
    );

    sections.forEach(section => sectionObserver.observe(section));
  }

  /**
   * 6. Weapon Card Hover Stats
   * Note: This is handled purely by CSS hover states.
   * The HTML structure should be:
   * <div class="weapon-card">
   *   <div class="weapon-stats">...</div>
   * </div>
   *
   * CSS handles the visibility transition on .weapon-card:hover .weapon-stats
   * No JS needed unless you want touch support on mobile.
   */

  // Optional: Add touch support for weapon cards on mobile
  function setupWeaponCardTouch() {
    const weaponCards = document.querySelectorAll('.weapon-card');

    if (!weaponCards.length) return;

    weaponCards.forEach(card => {
      card.addEventListener('touchstart', function(e) {
        // Toggle active state on touch devices
        const isActive = this.classList.contains('touch-active');

        // Remove active from all cards
        weaponCards.forEach(c => c.classList.remove('touch-active'));

        // Toggle current card
        if (!isActive) {
          this.classList.add('touch-active');
        }
      }, { passive: true });
    });

    // Close weapon cards on touch outside
    document.addEventListener('touchstart', (e) => {
      if (!e.target.closest('.weapon-card')) {
        weaponCards.forEach(card => card.classList.remove('touch-active'));
      }
    }, { passive: true });
  }

  // Initialize everything when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      init();
      setupWeaponCardTouch();
    });
  } else {
    init();
    setupWeaponCardTouch();
  }

})();
